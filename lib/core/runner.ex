defmodule ExEssentials.Core.Runner do
  @moduledoc """
  A small flow builder inspired by `Ecto.Multi`.

  `ExEssentials.Core.Runner` helps you model and execute a flow as a sequence of **named steps**.
  Each step contributes a value to a shared map called `changes`.

  This module is designed to be **built first** and **executed later**:

    * `put/3`, `run/3`, and `run_async/3` only register steps
    * execution happens only when calling `finish/1` or `finish/2`

  The execution model is **fail-fast**:

    * steps run in the order they were registered
    * when a step returns `{:error, reason}`, the flow stops immediately
    * the error includes the failing step name and the `changes` accumulated so far

  ## Steps

  Steps are always registered with a unique name (`atom()`). Names are used:

    * as keys in the resulting `changes` map
    * to identify the failing step in case of an error

  Supported step types:

    * `put/3` - seeds a value into `changes`
    * `run/3` - registers a synchronous step executed in order
    * `run_async/3` - registers an asynchronous step executed concurrently

  ## Asynchronous steps

  Asynchronous steps are queued as the flow is traversed and are executed concurrently when the
  flow needs to synchronize results:

    * before running a synchronous step (`run/3`)
    * at the end of the flow

  Each asynchronous step runs with a **snapshot** of `changes` from the moment the async step
  is registered during execution.

  ## Return values

  `finish/1` returns one of these tuples:

    * `{:ok, changes}`
    * `{:error, step, reason, changes_before}`

  `finish/2` executes the flow and forwards the result tuple to a user function, allowing you to
  transform it into any shape you want.

  ## Examples

  ### Basic flow

      runner =
        ExEssentials.Core.Runner.new(timeout: 5_000)
        |> ExEssentials.Core.Runner.put(:value, 1)
        |> ExEssentials.Core.Runner.run(:double, fn %{value: v} -> {:ok, v * 2} end)
        |> ExEssentials.Core.Runner.run(:triple, fn %{value: v} -> {:ok, v * 3} end)

      ExEssentials.Core.Runner.finish(runner)
      #=> {:ok, %{value: 1, double: 2, triple: 3}}

  ### Mixing sync and async

      runner =
        ExEssentials.Core.Runner.new(timeout: 5_000)
        |> ExEssentials.Core.Runner.put(:value, 1)
        |> ExEssentials.Core.Runner.run(:sync_step, fn _ -> {:ok, 2} end)
        |> ExEssentials.Core.Runner.run_async(:async_step, fn _ -> {:ok, 3} end)
        |> ExEssentials.Core.Runner.run(:sum, fn %{value: a, sync_step: b, async_step: c} -> {:ok, a + b + c} end)

      ExEssentials.Core.Runner.finish(runner)
      #=> {:ok, %{value: 1, sync_step: 2, async_step: 3, sum: 6}}

  ### Error handling

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:value, 1)
        |> ExEssentials.Core.Runner.run(:may_fail, fn _ -> {:error, :boom} end)
        |> ExEssentials.Core.Runner.run(:never_runs, fn _ -> {:ok, :ignored} end)

      ExEssentials.Core.Runner.finish(runner)
      #=> {:error, :may_fail, :boom, %{value: 1}}

  ### Transforming the result with `finish/2`

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:value, 1)
        |> ExEssentials.Core.Runner.run(:double, fn %{value: v} -> {:ok, v * 2} end)

      ExEssentials.Core.Runner.finish(runner, fn
        {:ok, %{double: result}} -> {:ok, result}
        {:error, step, reason, _changes} -> {:error, step, reason}
      end)
      #=> {:ok, 2}

  """
  alias ExEssentials.Core.Runner

  defstruct steps: [],
            changes: %{},
            failed?: false,
            error_reason: nil,
            failed_step: nil,
            timeout: 5000

  @typedoc """
  A single registered step in a flow.

  Steps are registered during build time and executed during `finish/1`.

    * `{:put, name, value}` - seeds a value
    * `{:sync, name, fun}` - runs synchronously
    * `{:async, name, fun}` - runs concurrently
    * `{:branch, predicate, on_true}` - conditionally injects more steps at runtime
    * `{:switch, selector}` - injects more steps at runtime based on `changes`
  """
  @type step ::
          {:put, step :: atom(), value :: any()}
          | {:sync, step :: atom(), (map() -> {:ok, any()} | {:error, any()})}
          | {:async, step :: atom(), (map() -> {:ok, any()} | {:error, any()})}
          | {:branch, predicate :: (map() -> boolean()), on_true :: (Runner.t() -> Runner.t())}
          | {:switch, selector :: (map() -> (Runner.t() -> Runner.t()))}

  @typedoc """
  The runner struct.

  The `steps` field stores the planned execution steps and `changes` stores seeded values.
  """
  @type t :: %Runner{
          steps: list(step()),
          changes: map(),
          failed?: boolean(),
          error_reason: any(),
          failed_step: step :: atom() | nil,
          timeout: integer()
        }

  @typedoc """
  Result returned by `finish/1`.

  On success, returns the final `changes` map.
  On error, returns the failing step name, the reason, and the `changes` accumulated so far.
  """
  @type finish_result ::
          {:ok, changes :: map()}
          | {:error, step :: atom(), reason :: any(), changes_before :: map()}

  @doc """
  Creates a new runner.

  ## Options

    * `:timeout` - timeout (in milliseconds) used when awaiting asynchronous steps.

  ## Examples

      iex> ExEssentials.Core.Runner.new().timeout
      5000

      iex> ExEssentials.Core.Runner.new(timeout: 10_000).timeout
      10000

  """
  @spec new(opts :: keyword()) :: Runner.t()
  def new(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    %Runner{timeout: timeout}
  end

  @doc """
  Seeds a value into `changes` under `step_name` and registers a `:put` step.

  Values seeded via `put/3` are immediately available in `runner.changes`, which is useful when
  composing flows with `branch/3` and `switch/2`.

  Raises `ArgumentError` if the step name has already been used.

  ## Examples

      iex> runner = ExEssentials.Core.Runner.new() |> ExEssentials.Core.Runner.put(:a, 1)
      iex> runner.changes
      %{a: 1}

  """
  @spec put(runner :: Runner.t(), step_name :: atom(), value :: any()) :: Runner.t()
  def put(runner = %Runner{failed?: true}, _step_name, _value), do: runner

  def put(runner = %Runner{changes: changes, steps: steps}, step_name, value)
      when is_atom(step_name) do
    validate_unique_step!(runner, step_name)
    changes = Map.put(changes, step_name, value)
    steps = steps ++ [{:put, step_name, value}]
    %Runner{runner | changes: changes, steps: steps}
  end

  @doc """
  Registers a synchronous step.

  The given function is executed during `finish/1` and receives the current `changes` map.

  The function must return:

    * `{:ok, result}` - stores `result` under the step name
    * `{:error, reason}` - stops the flow with an error

  Raises `ArgumentError` if the step name has already been used.

  ## Examples

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:value, 2)
        |> ExEssentials.Core.Runner.run(:square, fn %{value: v} -> {:ok, v * v} end)

      ExEssentials.Core.Runner.finish(runner)
      #=> {:ok, %{value: 2, square: 4}}

  """
  @spec run(
          runner :: Runner.t(),
          step_name :: atom(),
          function :: (changes :: map() -> {:ok, result :: any()} | {:error, reason :: any()})
        ) :: Runner.t()
  def run(runner = %Runner{failed?: true}, _step_name, _function), do: runner

  def run(runner = %Runner{steps: steps}, step_name, function)
      when is_function(function, 1) and is_atom(step_name) do
    validate_unique_step!(runner, step_name)
    steps = steps ++ [{:sync, step_name, function}]
    %Runner{runner | steps: steps}
  end

  @doc """
  Registers an asynchronous step.

  Asynchronous steps are executed concurrently during `finish/1`. Their results are merged into
  `changes` under their step names.

  Raises `ArgumentError` if the step name has already been used.

  ## Examples

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:value, 2)
        |> ExEssentials.Core.Runner.run_async(:double, fn %{value: v} -> {:ok, v * 2} end)
        |> ExEssentials.Core.Runner.run(:sum, fn %{value: v, double: d} -> {:ok, v + d} end)

      ExEssentials.Core.Runner.finish(runner)
      #=> {:ok, %{value: 2, double: 4, sum: 6}}

  """
  @spec run_async(
          runner :: Runner.t(),
          step_name :: atom(),
          function :: (changes :: map() -> {:ok, result :: any()} | {:error, reason :: any()})
        ) :: Runner.t()
  def run_async(runner = %Runner{failed?: true}, _step_name, _function), do: runner

  def run_async(runner = %Runner{steps: steps}, step_name, function)
      when is_function(function, 1) and is_atom(step_name) do
    validate_unique_step!(runner, step_name)
    steps = steps ++ [{:async, step_name, function}]
    %Runner{runner | steps: steps}
  end

  @doc """
  Applies a continuation function to the runner.

  This is a convenience for composing flow-building functions.

  ## Examples

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:a, 1)
        |> ExEssentials.Core.Runner.then(fn r -> ExEssentials.Core.Runner.put(r, :b, 2) end)

      runner.changes
      #=> %{a: 1, b: 2}

  """
  @spec then(
          runner :: Runner.t(),
          function :: (runner :: Runner.t() -> Runner.t())
        ) :: Runner.t()
  def then(runner = %Runner{failed?: true}, _fun), do: runner
  def then(runner = %Runner{}, fun) when is_function(fun, 1), do: fun.(runner)

  @doc """
  Conditionally applies `on_true` when `predicate` evaluates to `true`.

  The predicate is evaluated at runtime during `finish/1`, using the current `changes` map.

  ## Examples

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:status, :rejected)
        |> ExEssentials.Core.Runner.branch(
          fn %{status: status} -> status == :rejected end,
          fn r -> ExEssentials.Core.Runner.put(r, :compensate, true) end
        )

      ExEssentials.Core.Runner.finish(runner)
      #=> {:ok, %{status: :rejected, compensate: true}}

  """
  @spec branch(
          runner :: Runner.t(),
          predicate :: (changes :: map() -> boolean()),
          on_true :: (runner :: Runner.t() -> Runner.t())
        ) :: Runner.t()
  def branch(runner = %Runner{failed?: true}, _predicate, _on_true), do: runner

  def branch(runner = %Runner{steps: steps}, predicate, on_true)
      when is_function(predicate, 1) and is_function(on_true, 1) do
    steps = steps ++ [{:branch, predicate, on_true}]
    %Runner{runner | steps: steps}
  end

  @doc """
  Selects and applies a continuation at runtime during `finish/1`, based on the current `changes` map.

  The selector must return a function that receives the runner.

  ## Examples

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:status, :settled)
        |> ExEssentials.Core.Runner.switch(fn
          %{status: :settled} -> fn r -> ExEssentials.Core.Runner.put(r, :final, :ok) end
          _ -> fn r -> ExEssentials.Core.Runner.put(r, :final, :error) end
        end)

      ExEssentials.Core.Runner.finish(runner)
      #=> {:ok, %{status: :settled, final: :ok}}

  """
  @spec switch(
          runner :: Runner.t(),
          selector :: (changes :: map() -> (runner :: Runner.t() -> Runner.t()))
        ) :: Runner.t()
  def switch(runner = %Runner{failed?: true}, _selector), do: runner

  def switch(runner = %Runner{steps: steps}, selector) when is_function(selector, 1) do
    steps = steps ++ [{:switch, selector}]
    %Runner{runner | steps: steps}
  end

  @doc """
  Executes the flow and returns the execution result.

  Returns:

    * `{:ok, changes}` when all steps succeed
    * `{:error, step, reason, changes_before}` when a step fails

  ## Examples

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:value, 1)
        |> ExEssentials.Core.Runner.run(:double, fn %{value: v} -> {:ok, v * 2} end)

      ExEssentials.Core.Runner.finish(runner)
      #=> {:ok, %{value: 1, double: 2}}

  """
  @spec finish(runner :: Runner.t()) ::
          {:ok, changes :: map()} | {:error, step :: atom(), reason :: any(), changes_before :: map()}
  def finish(runner = %Runner{}), do: execute_flow(runner)

  @doc """
  Executes the flow and passes the result to the given function.

  This is useful when you want to normalize the output or extract a single value.

  ## Examples

      runner =
        ExEssentials.Core.Runner.new()
        |> ExEssentials.Core.Runner.put(:value, 1)
        |> ExEssentials.Core.Runner.run(:double, fn %{value: v} -> {:ok, v * 2} end)

      ExEssentials.Core.Runner.finish(runner, fn
        {:ok, %{double: result}} -> {:ok, result}
        {:error, step, reason, _changes} -> {:error, step, reason}
      end)
      #=> {:ok, 2}

  """
  @spec finish(runner :: Runner.t(), function :: (finish_result() -> any())) :: any()
  def finish(runner = %Runner{}, function) when is_function(function, 1) do
    runner
    |> execute_flow()
    |> function.()
  end

  defp execute_flow(%Runner{steps: steps, changes: seed_changes, timeout: timeout}) do
    acc = %{changes: seed_changes, pending_async: [], timeout: timeout}
    execute_steps(steps, acc)
  end

  defp execute_steps([], acc), do: finalize_flow(acc)

  defp execute_steps([step | rest], acc) do
    step
    |> reduce_step(acc)
    |> handle_execute_step_result(rest)
  end

  defp handle_execute_step_result({:cont, acc2}, rest),
    do: execute_steps(rest, acc2)

  defp handle_execute_step_result({:inject, injected_steps, acc2}, rest),
    do: handle_execute_injection(injected_steps, acc2, rest)

  defp handle_execute_step_result({:halt, error}, _rest),
    do: error

  defp handle_execute_injection(injected_steps, acc2, rest) do
    injected_steps
    |> validate_injected_steps(rest, acc2.changes)
    |> handle_injection_validation(injected_steps, acc2, rest)
  end

  defp handle_injection_validation(:ok, injected_steps, acc2, rest),
    do: execute_steps(injected_steps ++ rest, acc2)

  defp handle_injection_validation({:error, error}, _injected_steps, _acc2, _rest),
    do: error

  defp reduce_step({:async, step_name, fun}, acc),
    do: {:cont, enqueue_async(acc, step_name, fun)}

  defp reduce_step({:put, step_name, value}, acc),
    do: handle_put_step(acc, step_name, value)

  defp reduce_step({:sync, step_name, fun}, acc),
    do: handle_sync_step(acc, step_name, fun)

  defp reduce_step({:branch, predicate, on_true}, acc),
    do: handle_branch_step(acc, predicate, on_true)

  defp reduce_step({:switch, selector}, acc),
    do: handle_switch_step(acc, selector)

  defp handle_branch_step(acc, predicate, on_true) do
    acc
    |> flush_pending_async()
    |> handle_branch_flush_result(predicate, on_true)
  end

  defp handle_branch_flush_result({:ok, acc2}, predicate, on_true),
    do: handle_branch_decision(predicate.(acc2.changes), acc2, on_true)

  defp handle_branch_flush_result({:error, step, reason, changes_before}, _predicate, _on_true),
    do: {:halt, {:error, step, reason, changes_before}}

  defp handle_branch_decision(true, acc2, on_true),
    do: inject_branch_steps(acc2, on_true)

  defp handle_branch_decision(false, acc2, _on_true),
    do: {:cont, acc2}

  defp inject_branch_steps(acc2, on_true) do
    injected_runner = build_injected_runner(acc2, on_true)
    {:inject, injected_runner.steps, %{acc2 | changes: injected_runner.changes}}
  end

  defp handle_switch_step(acc, selector) do
    case flush_pending_async(acc) do
      {:ok, acc2} ->
        continuation = selector.(acc2.changes)
        injected_runner = build_injected_runner(acc2, continuation)
        {:inject, injected_runner.steps, %{acc2 | changes: injected_runner.changes}}

      {:error, step, reason, changes_before} ->
        {:halt, {:error, step, reason, changes_before}}
    end
  end

  defp build_injected_runner(%{changes: changes, timeout: timeout}, fun) do
    runner = %Runner{
      steps: [],
      changes: changes,
      failed?: false,
      error_reason: nil,
      failed_step: nil,
      timeout: timeout
    }

    fun.(runner)
  end

  defp handle_put_step(acc, step_name, value) do
    case flush_pending_async(acc) do
      {:ok, acc2} -> {:cont, put_change(acc2, step_name, value)}
      {:error, step, reason, changes_before} -> {:halt, {:error, step, reason, changes_before}}
    end
  end

  defp handle_sync_step(acc, step_name, fun) do
    with {:ok, acc2} <- flush_pending_async(acc),
         {:ok, changes2} <- run_sync_step(acc2.changes, step_name, fun) do
      {:cont, %{acc2 | changes: changes2}}
    else
      {:error, step, reason, changes_before} ->
        {:halt, {:error, step, reason, changes_before}}
    end
  end

  defp finalize_flow(%{pending_async: [], changes: changes}),
    do: {:ok, changes}

  defp finalize_flow(acc) do
    case flush_pending_async(acc) do
      {:ok, acc2} -> {:ok, acc2.changes}
      {:error, step, reason, changes_before} -> {:error, step, reason, changes_before}
    end
  end

  defp enqueue_async(acc, step_name, fun),
    do: %{acc | pending_async: acc.pending_async ++ [{step_name, fun, acc.changes}]}

  defp put_change(acc, step_name, value),
    do: %{acc | changes: Map.put(acc.changes, step_name, value)}

  defp run_sync_step(changes, step_name, fun) do
    case fun.(changes) do
      {:ok, result} -> {:ok, Map.put(changes, step_name, result)}
      {:error, reason} -> {:error, step_name, reason, changes}
    end
  end

  defp flush_pending_async(acc = %{pending_async: []}), do: {:ok, acc}

  defp flush_pending_async(acc = %{pending_async: pending_async, timeout: timeout}) do
    pending_async
    |> async_stream_results(timeout)
    |> merge_async_results(clear_pending_async(acc))
  end

  defp async_stream_results(pending_async, timeout) do
    pending_async
    |> Task.async_stream(&execute_async_item/1, timeout: timeout, ordered: false)
    |> Enum.to_list()
  end

  defp execute_async_item({step_name, fun, snapshot_changes}),
    do: {step_name, fun.(snapshot_changes)}

  defp clear_pending_async(acc),
    do: %{acc | pending_async: []}

  defp merge_async_results(results, acc),
    do: Enum.reduce_while(results, {:ok, acc}, &merge_async_results_reduce/2)

  defp merge_async_results_reduce(item, {:ok, acc}),
    do: handle_async_item(item, acc)

  defp merge_async_results_reduce(_item, err = {:error, _step, _reason, _changes_before}),
    do: {:halt, err}

  defp handle_async_item({:ok, {step_name, {:ok, result}}}, acc),
    do: {:cont, {:ok, put_async_result(acc, step_name, result)}}

  defp handle_async_item({:ok, {step_name, {:error, reason}}}, acc),
    do: {:halt, {:error, step_name, reason, acc.changes}}

  defp handle_async_item({:exit, _reason}, acc),
    do: {:halt, {:error, :async_task_exit, :task_exit, acc.changes}}

  defp handle_async_item(other, acc),
    do: {:halt, {:error, :async_unknown, other, acc.changes}}

  defp put_async_result(acc, step_name, result),
    do: %{acc | changes: Map.put(acc.changes, step_name, result)}

  defp validate_unique_step!(%Runner{steps: steps}, step_name) do
    if step_step_name_exists?(steps, step_name) do
      raise ArgumentError, "The step name '#{step_name}' has already been used in the flow."
    end
  end

  defp step_step_name_exists?(steps, step_name),
    do: Enum.any?(steps, &step_name_matches?(&1, step_name))

  defp step_name_matches?({_type, step_name, _value_or_fun}, compare_step_name),
    do: step_name == compare_step_name

  defp validate_injected_steps(injected_steps, remaining_steps, changes_before) do
    injected_names = collect_step_names(injected_steps)
    remaining_names = collect_step_names(remaining_steps)

    case duplicated_name(injected_names, remaining_names) do
      nil -> :ok
      name -> {:error, {:error, :runner, {:duplicated_step_name, name}, changes_before}}
    end
  end

  defp collect_step_names(steps), do: collect_step_names(steps, [])

  defp collect_step_names([], acc), do: Enum.reverse(acc)

  defp collect_step_names([step | rest], acc) do
    case injected_step_name(step) do
      nil -> collect_step_names(rest, acc)
      name -> collect_step_names(rest, [name | acc])
    end
  end

  defp injected_step_name({:put, name, _}), do: name
  defp injected_step_name({:sync, name, _}), do: name
  defp injected_step_name({:async, name, _}), do: name
  defp injected_step_name(_), do: nil

  defp duplicated_name(injected_names, remaining_names) do
    injected_set = MapSet.new(injected_names)
    find_duplicate(remaining_names, injected_set)
  end

  defp find_duplicate([], _set), do: nil

  defp find_duplicate([name | rest], set),
    do: if(MapSet.member?(set, name), do: name, else: find_duplicate(rest, set))
end
