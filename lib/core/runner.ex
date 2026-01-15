defmodule ExEssentials.Core.Runner do
  @moduledoc """
    A small, composable flow runner for building step-by-step pipelines with optional asynchronous work.

    `ExEssentials.Core.Runner` lets you accumulate results across named steps while keeping a single
    immutable `changes` map that is passed to each step function.

    It supports two kinds of steps:

      - **Synchronous steps** via `run/3`, executed immediately and stored in `changes`.
      - **Asynchronous steps** via `run_async/3`, executed in a separate `Task` and merged into `changes`
        when the runner is about to continue synchronously (or when `finish/2` is called).

    The runner is **fail-fast**:

      - When a step returns `{:error, reason}`, the runner is marked as failed and subsequent calls to
        `put/3`, `run/3`, or `run_async/3` become no-ops.
      - Step names must be unique within a flow. Reusing a step name raises an `ArgumentError`.

    Asynchronous steps are awaited using `Task.yield_many/2` with the configured `:timeout` (in milliseconds).
    Tasks that do not respond within the timeout are shutdown and their results are not merged.

    When you are done building the flow, call `finish/2` to await any remaining async work and receive a
    final result in the shape of either `{:ok, changes}` or `{:error, failed_step, reason, changes_before_error}`.
  """
  alias ExEssentials.Core.Runner

  defstruct steps: [], async_tasks: [], changes: %{}, failed?: false, error_reason: nil, failed_step: nil, timeout: 5000

  @type step :: {:sync, atom(), any()} | {:async, atom(), Task.t()}

  @type t :: %Runner{
          steps: list(step()),
          async_tasks: list(Task.t()),
          changes: map(),
          failed?: boolean(),
          error_reason: any(),
          failed_step: atom(),
          timeout: integer()
        }

  @doc """
    Creates a new runner.

    Options:

      - `:timeout` - the timeout (in milliseconds) used when awaiting async steps (default: `5000`).

    ## Examples

        iex> runner = ExEssentials.Core.Runner.new(timeout: 1_000)
        iex> runner.timeout
        1000
  """
  @spec new(opts :: Keyword.t()) :: t()
  def new(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    %Runner{timeout: timeout}
  end

  @doc """
    Inserts a value into the runner under `step_name`.

    This is useful for seeding the flow with inputs or precomputed values.

    If the runner is already marked as failed, this function returns the runner unchanged.

    ## Examples

        iex> runner = ExEssentials.Core.Runner.new()
        iex> runner = ExEssentials.Core.Runner.put(runner, :user_id, 123)
        iex> runner.changes
        %{user_id: 123}
  """
  @spec put(runner :: t(), step_name :: atom(), value :: any()) :: t()
  def put(runner = %Runner{failed?: true}, _step_name, _value), do: runner

  def put(runner = %Runner{changes: changes, steps: steps}, step_name, value)
      when is_atom(step_name) do
    changes = Map.put(changes, step_name, value)
    steps = steps ++ [{:sync, step_name, value}]
    %Runner{runner | changes: changes, steps: steps}
  end

  @doc """
    Executes a synchronous step and stores its result in `changes`.

    Before running the step, the runner will await any pending async tasks so that their results are
    available to the step.

    The step function receives the current `changes` map and must return either:

      - `{:ok, result}` to continue the flow, storing `result` under `step_name`.
      - `{:error, reason}` to fail the flow, storing `reason` under `step_name` and marking the runner as failed.

    Step names must be unique; reusing the same `step_name` raises an `ArgumentError`.

    If the runner is already marked as failed, this function returns the runner unchanged.

    ## Examples

        iex> runner = ExEssentials.Core.Runner.new()
        iex> runner = ExEssentials.Core.Runner.put(runner, :a, 2)
        iex> runner = ExEssentials.Core.Runner.run(runner, :b, fn changes -> {:ok, changes.a * 3} end)
        iex> runner.changes
        %{a: 2, b: 6}

        iex> runner = ExEssentials.Core.Runner.new()
        iex> runner = ExEssentials.Core.Runner.run(runner, :step, fn _changes -> {:error, :boom} end)
        iex> {runner.failed?, runner.failed_step, runner.error_reason}
        {true, :step, :boom}
  """
  @spec run(
          runner :: t(),
          step_name :: atom(),
          function :: (changes :: map() -> {:ok, result :: any()} | {:error, reason :: any()})
        ) :: t()
  def run(runner = %Runner{failed?: true}, _step_name, _function),
    do: runner

  def run(runner, step_name, function)
      when is_function(function, 1) and is_atom(step_name) do
    validate_unique_step!(runner, step_name)

    case await_pending_async_tasks(runner) do
      runner = %Runner{failed?: true} -> runner
      runner -> execute_step(runner, step_name, function, :sync)
    end
  end

  @doc """
    Spawns an asynchronous step as a `Task`.

    The step function receives the current `changes` map *as it exists at the time the task is spawned*.
    The task result is merged into `changes` the next time the runner needs to synchronize (on `run/3`
    or `finish/2`).

    If the runner is already marked as failed, this function returns the runner unchanged.

    Step names must be unique; reusing the same `step_name` raises an `ArgumentError`.

    Notes on timeouts:

      - Async tasks are awaited with the runner's configured `:timeout`.
      - If a task does not respond within the timeout, it is shutdown and its result is not merged.

    ## Examples

        iex> runner = ExEssentials.Core.Runner.new(timeout: 5_000)
        iex> runner = ExEssentials.Core.Runner.put(runner, :base, 10)
        iex> runner = ExEssentials.Core.Runner.run_async(runner, :double, fn changes -> {:ok, changes.base * 2} end)
        iex> runner = ExEssentials.Core.Runner.run(runner, :plus_one, fn changes -> {:ok, changes.base + 1} end)
        iex> Map.take(runner.changes, [:base, :double, :plus_one])
        %{base: 10, double: 20, plus_one: 11}
  """
  @spec run_async(
          runner :: t(),
          step_name :: atom(),
          function :: (changes :: map() -> {:ok, result :: any()} | {:error, reason :: any()})
        ) :: t()
  def run_async(runner = %Runner{failed?: true}, _step_name, _function),
    do: runner

  def run_async(runner, step_name, function)
      when is_function(function, 1) and is_atom(step_name) do
    validate_unique_step!(runner, step_name)
    execute_step_async(runner, step_name, function)
  end

  @doc """
  Continues the runner pipeline by applying `fun` to the current runner.

  This is useful to keep composing steps without calling `finish/2` in the middle
  of the pipeline.

  If the runner is already marked as failed, this function returns the runner unchanged.

  ## Examples

      iex> ExEssentials.Core.Runner.new()
      ...> |> ExEssentials.Core.Runner.put(:a, 1)
      ...> |> ExEssentials.Core.Runner.then(fn r -> ExEssentials.Core.Runner.put(r, :b, 2) end)
      ...> |> ExEssentials.Core.Runner.finish(fn result -> result end)
      {:ok, %{a: 1, b: 2}}
  """
  @spec then(runner :: t(), fun :: (t() -> t())) :: t()
  def then(runner = %Runner{failed?: true}, _fun), do: runner

  def then(runner = %Runner{}, fun) when is_function(fun, 1),
    do: fun.(runner)

  @doc """
  Conditionally continues the runner pipeline.

  `predicate` receives the current `changes` map and must return a boolean.
  When `predicate` returns `true`, `on_true` is executed receiving the current runner.
  When `predicate` returns `false`, the runner is returned unchanged.

  If the runner is already marked as failed, this function returns the runner unchanged.

  ## Examples

      iex> ExEssentials.Core.Runner.new()
      ...> |> ExEssentials.Core.Runner.put(:status, :rejected)
      ...> |> ExEssentials.Core.Runner.branch(
      ...>   fn %{status: status} -> status == :rejected end,
      ...>   fn r -> ExEssentials.Core.Runner.put(r, :compensation, :done) end
      ...> )
      ...> |> ExEssentials.Core.Runner.finish(fn result -> result end)
      {:ok, %{status: :rejected, compensation: :done}}
  """
  @spec branch(runner :: t(), predicate :: (map() -> boolean()), on_true :: (t() -> t())) :: t()
  def branch(runner = %Runner{failed?: true}, _predicate, _on_true), do: runner

  def branch(runner = %Runner{changes: changes}, predicate, on_true)
      when is_function(predicate, 1) and is_function(on_true, 1) do
    if predicate.(changes), do: on_true.(runner), else: runner
  end

  @doc """
  Selects the next continuation based on the current `changes`.

  The given function must return a continuation function `(runner -> runner)`.
  This enables pattern-matching on `changes` while keeping the pipeline linear.

  If the runner is already marked as failed, this function returns the runner unchanged.

  ## Examples

      iex> ExEssentials.Core.Runner.new()
      ...> |> ExEssentials.Core.Runner.put(:status, :settled)
      ...> |> ExEssentials.Core.Runner.switch(fn
      ...>   %{status: :settled} -> fn r -> ExEssentials.Core.Runner.put(r, :final, :ok) end
      ...>   _ -> fn r -> ExEssentials.Core.Runner.put(r, :final, :error) end
      ...> end)
      ...> |> ExEssentials.Core.Runner.finish(fn result -> result end)
      {:ok, %{status: :settled, final: :ok}}
  """
  @spec switch(runner :: t(), selector :: (map() -> (t() -> t()))) :: t()
  def switch(runner = %Runner{failed?: true}, _selector), do: runner

  def switch(runner = %Runner{changes: changes}, selector)
      when is_function(selector, 1) do
    continuation = selector.(changes)
    continuation.(runner)
  end

  @doc """
    Finalizes the flow and returns the output of `function`.

    This function awaits any pending async tasks (subject to the runner's `:timeout`) and then calls
    `function` with one of the following results:

      - `{:ok, changes}` when all executed steps completed successfully.
      - `{:error, failed_step, reason, changes_before_error}` when a step failed.

    `changes_before_error` contains only the accumulated values up to (but not including) the failing step.

    ## Examples

        iex> ExEssentials.Core.Runner.new()
        ...> |> ExEssentials.Core.Runner.put(:a, 1)
        ...> |> ExEssentials.Core.Runner.run(:b, fn ch -> {:ok, ch.a + 1} end)
        ...> |> ExEssentials.Core.Runner.finish(fn result -> result end)
        {:ok, %{a: 1, b: 2}}

        iex> ExEssentials.Core.Runner.new()
        ...> |> ExEssentials.Core.Runner.put(:a, 1)
        ...> |> ExEssentials.Core.Runner.run(:b, fn _ch -> {:error, :nope} end)
        ...> |> ExEssentials.Core.Runner.run(:c, fn _ch -> {:ok, :never_runs} end)
        ...> |> ExEssentials.Core.Runner.finish(fn result -> result end)
        {:error, :b, :nope, %{a: 1}}
  """
  @spec finish(runner :: t(), function :: (changes :: {:ok, map()} | {:error, atom(), any()} -> any())) :: any()
  def finish(runner = %Runner{}, function),
    do: runner |> await_pending_async_tasks() |> execute_finish(function)

  defp execute_step(runner, step_name, function, type) do
    %Runner{changes: changes} = runner
    function |> run_step_function(changes) |> update_runner(runner, step_name, type)
  end

  defp execute_step_async(runner, step_name, function) do
    %Runner{async_tasks: async_tasks, changes: changes, steps: steps} = runner
    async_function = fn -> execute_async_step(step_name, function, changes) end
    task = Task.async(async_function)
    async_tasks = async_tasks ++ [task]
    steps = steps ++ [{:async, step_name, task}]
    %Runner{runner | steps: steps, async_tasks: async_tasks}
  end

  defp execute_async_step(step_name, function, changes) do
    case run_step_function(function, changes) do
      {:ok, result} -> {step_name, {:ok, result}}
      {:error, reason} -> {step_name, {:error, reason}}
    end
  end

  defp run_step_function(function, changes), do: function.(changes)

  defp update_runner({:ok, result}, runner, step_name, type) do
    %Runner{steps: steps, changes: changes} = runner
    steps = steps ++ [{type, step_name, result}]
    changes = Map.put(changes, step_name, result)
    %Runner{runner | changes: changes, steps: steps}
  end

  defp update_runner({:error, reason}, runner, step_name, _type) do
    %Runner{changes: changes} = runner
    changes = Map.put(changes, step_name, reason)
    %Runner{runner | changes: changes, error_reason: reason, failed?: true, failed_step: step_name}
  end

  defp await_pending_async_tasks(runner = %Runner{async_tasks: []}), do: runner

  defp await_pending_async_tasks(runner) do
    %Runner{async_tasks: tasks, changes: changes, timeout: timeout} = runner
    accumulate_async_results = %{changes: changes, failed_step: nil, error_reason: nil}

    tasks
    |> Task.yield_many(timeout)
    |> Enum.reduce(accumulate_async_results, &process_async_task/2)
    |> update_runner_with_async_results(runner)
  end

  defp process_async_task({_task, {:ok, {step_name, {:ok, result}}}}, accumulate) do
    %{changes: changes} = accumulate
    changes = Map.put(changes, step_name, result)
    %{accumulate | changes: changes}
  end

  defp process_async_task({_task, {:ok, {step_name, {:error, reason}}}}, accumulate) do
    %{changes: changes} = accumulate
    changes = Map.put(changes, step_name, reason)
    %{changes: changes, failed_step: step_name, error_reason: reason}
  end

  defp process_async_task({task, nil}, accumulate),
    do: handle_task_timeout(task, accumulate)

  defp process_async_task(_other, accumulate),
    do: accumulate

  defp handle_task_timeout(task, accumulate) do
    Task.shutdown(task, :brutal_kill)
    accumulate
  end

  defp update_runner_with_async_results(%{changes: changes, failed_step: nil}, runner),
    do: %Runner{runner | async_tasks: [], changes: changes}

  defp update_runner_with_async_results(accumulate, runner) do
    %{changes: changes, failed_step: failed_step, error_reason: reason} = accumulate

    runner
    |> Map.put(:async_tasks, [])
    |> Map.put(:changes, changes)
    |> Map.put(:failed?, true)
    |> Map.put(:failed_step, failed_step)
    |> Map.put(:error_reason, reason)
  end

  defp execute_finish(runner = %Runner{failed?: true}, function) do
    %Runner{changes: changes, failed_step: failed_step, error_reason: reason} = runner
    changes_before_error = extract_changes_before_error(changes, failed_step)
    runner_result = {:error, failed_step, reason, changes_before_error}
    function.(runner_result)
  end

  defp execute_finish(%Runner{changes: changes}, function) do
    runner_result = {:ok, changes}
    function.(runner_result)
  end

  defp extract_changes_before_error(changes, error_step) do
    changes
    |> Enum.take_while(&before_error_step?(&1, error_step))
    |> Map.new()
  end

  defp before_error_step?({step, _change}, compare_step), do: step != compare_step

  defp validate_unique_step!(%Runner{steps: steps}, step_name) do
    if step_step_name_exists?(steps, step_name) do
      raise ArgumentError, "The step name '#{step_name}' has already been used in the flow."
    end
  end

  defp step_step_name_exists?(steps, step_name),
    do: Enum.any?(steps, &step_name_matches?(&1, step_name))

  defp step_name_matches?({_type, step_name, _result_or_task}, compare_step_name),
    do: step_name == compare_step_name
end
