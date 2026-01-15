defmodule ExEssentials.Core.RunnerTest do
  use ExUnit.Case

  doctest ExEssentials.Core.Runner

  alias ExEssentials.Core.Runner

  describe "new/1" do
    test "should return a Runner struct with default timeout" do
      runner = Runner.new()
      assert %Runner{timeout: 5000} == runner
    end

    test "should return a Runner struct with custom timeout" do
      runner = Runner.new(timeout: 10_000)
      assert %Runner{timeout: 10_000} == runner
    end
  end

  describe "put/3" do
    test "should return a Runner struct with the given step name and value" do
      runner = Runner.new()
      runner = Runner.put(runner, :step, "step_value")
      assert %Runner{changes: %{step: "step_value"}} = runner
    end

    test "should return the same runner without step value when it fails previously" do
      failed_runner = %Runner{failed?: true}
      assert %Runner{changes: %{}, failed?: true, steps: []} = Runner.put(failed_runner, :step, "step_value")
    end
  end

  describe "run/3" do
    test "should return updated runner with result when step is successful" do
      runner = Runner.new()
      function = fn _changes -> {:ok, :success} end
      assert %Runner{changes: %{step1: :success}, failed?: false} = Runner.run(runner, :step1, function)
    end

    test "should return the same runner when it fails previously" do
      failed_runner = %Runner{failed?: true}
      function = fn _changes -> {:ok, :success} end
      assert %Runner{failed?: true} == Runner.run(failed_runner, :step1, function)
    end
  end

  describe "run_async/3" do
    test "should return updated runner with task when step is async" do
      runner = Runner.new()
      async_function = fn _changes -> {:ok, :async_result} end

      assert %Runner{async_tasks: async_tasks} = Runner.run_async(runner, :async_step, async_function)
      assert is_list(async_tasks)
      assert length(async_tasks) == 1
    end

    test "should return the same runner when it fails previously" do
      failed_runner = %Runner{failed?: true}
      async_function = fn _changes -> {:ok, :async_result} end
      assert %Runner{failed?: true} == Runner.run(failed_runner, :async_step, async_function)
    end
  end

  describe "finish/2" do
    test "should return result when all steps succeed" do
      step_function = fn _changes -> {:ok, :result} end
      finish_function = fn {:ok, changes} -> changes end
      runner = [timeout: 100] |> Runner.new() |> Runner.run(:step, step_function)
      assert %{step: :result} == Runner.finish(runner, finish_function)
    end
  end

  describe "runner execution flow" do
    test "should return the correct result when running synchronous and asynchronous steps in order" do
      sync_step = fn _changes -> {:ok, 2} end

      async_step = fn _changes ->
        Process.sleep(100)
        {:ok, 3}
      end

      sum_step = fn %{value: num1, step: num2, async_step: num3} -> {:ok, num1 + num2 + num3} end
      finish_function = fn {:ok, %{sum: result}} -> {:ok, result} end

      Runner.new()
      |> Runner.put(:value, 1)
      |> Runner.run(:step, sync_step)
      |> Runner.run_async(:async_step, async_step)
      |> Runner.run(:sum, sum_step)
      |> Runner.finish(finish_function)
      |> assert_runner_result({:ok, 6})
    end

    test "should return the correct result when running synchronous steps" do
      num1_step = fn _changes -> {:ok, 2} end
      num2_step = fn _changes -> {:ok, 3} end
      sum_step = fn %{value: num1, step1: num2, step2: num3} -> {:ok, num1 + num2 + num3} end
      finish_function = fn {:ok, %{sum: result}} -> {:ok, result} end

      Runner.new()
      |> Runner.put(:value, 1)
      |> Runner.run(:step1, num1_step)
      |> Runner.run(:step2, num2_step)
      |> Runner.run(:sum, sum_step)
      |> Runner.finish(finish_function)
      |> assert_runner_result({:ok, 6})
    end

    test "should return the correct result when running asynchronous and synchronous steps with error" do
      sync_step = fn _changes -> {:ok, 2} end

      async_step = fn _changes ->
        Process.sleep(100)
        {:error, :some_error}
      end

      sum_step = fn %{value: num1, step: num2, async_step: num3} -> {:ok, num1 + num2 + num3} end
      finish_function = fn {:error, step, reason, _changes} -> {:error, step, reason} end

      Runner.new()
      |> Runner.put(:value, 1)
      |> Runner.run(:step, sync_step)
      |> Runner.run_async(:async_step, async_step)
      |> Runner.run(:sum_step, sum_step)
      |> Runner.finish(finish_function)
      |> assert_runner_result({:error, :async_step, :some_error})
    end

    test "should return the correct result when running synchronous step with error" do
      num1_step = fn _changes -> {:ok, 2} end
      num2_step = fn _changes -> {:error, :some_error} end
      sum_step = fn %{value: num1, step: num2, async_step: num3} -> {:ok, num1 + num2 + num3} end
      finish_function = fn {:error, step, reason, _changes} -> {:error, step, reason} end

      Runner.new()
      |> Runner.put(:value, 1)
      |> Runner.run(:step1, num1_step)
      |> Runner.run(:step2, num2_step)
      |> Runner.run(:sum, sum_step)
      |> Runner.finish(finish_function)
      |> assert_runner_result({:error, :step2, :some_error})
    end
  end

  describe "then/2" do
    test "should return updated runner when it is not failed" do
      runner =
        Runner.new()
        |> Runner.put(:a, 1)
        |> Runner.then(fn r -> Runner.put(r, :b, 2) end)

      assert runner.changes == %{a: 1, b: 2}
    end

    test "should return the same runner when it fails previously" do
      runner = %Runner{failed?: true, changes: %{a: 1}}

      result = Runner.then(runner, fn r -> Runner.put(r, :b, 2) end)

      assert result == runner
    end
  end

  describe "branch/3" do
    test "should return updated runner when predicate is true" do
      runner =
        Runner.new()
        |> Runner.put(:status, :rejected)
        |> Runner.branch(fn %{status: s} -> s == :rejected end, fn r -> Runner.put(r, :compensation, :done) end)

      assert runner.changes == %{status: :rejected, compensation: :done}
    end

    test "should return the same runner when predicate is false" do
      runner =
        Runner.new()
        |> Runner.put(:status, :settled)
        |> Runner.branch(fn %{status: s} -> s == :rejected end, fn r -> Runner.put(r, :compensation, :done) end)

      assert runner.changes == %{status: :settled}
    end

    test "should return the same runner when it fails previously" do
      runner = %Runner{failed?: true, changes: %{status: :rejected}}
      result = Runner.branch(runner, fn _ -> true end, fn r -> Runner.put(r, :compensation, :done) end)
      assert result == runner
    end
  end

  describe "switch/2" do
    test "should return updated runner when selecting a continuation" do
      runner =
        Runner.new()
        |> Runner.put(:status, :settled)
        |> Runner.switch(fn
          %{status: :settled} -> fn r -> Runner.put(r, :final, :ok) end
          _ -> fn r -> Runner.put(r, :final, :error) end
        end)

      assert runner.changes == %{status: :settled, final: :ok}
    end

    test "should return the same runner when it fails previously" do
      runner = %Runner{failed?: true, changes: %{status: :settled}}
      result = Runner.switch(runner, fn _ -> fn r -> Runner.put(r, :final, :ok) end end)
      assert result == runner
    end
  end

  defp assert_runner_result(runner_result, expected_result),
    do: assert(runner_result == expected_result)
end
