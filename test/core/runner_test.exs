defmodule ExEssentials.Core.RunnerTest do
  use ExUnit.Case

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

      assert %Runner{
               changes: %{},
               failed?: false,
               error_reason: nil,
               failed_step: nil,
               steps: [{:sync, :step1, ^function}],
               timeout: 5000
             } = Runner.run(runner, :step1, function)
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

      assert %Runner{
               changes: %{},
               failed?: false,
               error_reason: nil,
               failed_step: nil,
               steps: [{:async, :async_step, ^async_function}],
               timeout: 5000
             } = Runner.run_async(runner, :async_step, async_function)
    end

    test "should return the same runner when it fails previously" do
      failed_runner = %Runner{failed?: true}
      async_function = fn _changes -> {:ok, :async_result} end
      assert %Runner{failed?: true} == Runner.run_async(failed_runner, :async_step, async_function)
    end
  end

  describe "then/2" do
    test "should return updated runner when runner is not failed" do
      runner = Runner.new()
      func = fn runner -> %Runner{runner | changes: %{a: 1, b: 2}} end
      assert %Runner{changes: changes} = Runner.then(runner, func)
      assert %{a: 1, b: 2} == changes
    end

    test "should return same runner when runner is failed" do
      runner = %Runner{failed?: true, changes: %{a: 1}}
      func = fn runner -> %Runner{runner | changes: %{a: 1, b: 2}} end
      assert %Runner{failed?: true, changes: %{a: 1}} == Runner.then(runner, func)
    end
  end

  describe "branch/3" do
    test "should return updated runner when predicate is true" do
      runner = %Runner{changes: %{status: :rejected}}

      predicate = fn %{status: s} -> s == :rejected end
      func = fn runner -> %Runner{runner | changes: Map.put(runner.changes, :compensation, :done)} end

      assert %Runner{changes: changes} = Runner.branch(runner, predicate, func)
      assert %{status: :rejected, compensation: :done} == changes
    end

    test "should return same runner when predicate is false" do
      runner = %Runner{changes: %{status: :settled}}
      predicate = fn %{status: s} -> s == :rejected end
      func = fn runner -> %Runner{runner | changes: Map.put(runner.changes, :compensation, :done)} end
      assert %Runner{changes: changes} = Runner.branch(runner, predicate, func)
      assert %{status: :settled} == changes
    end

    test "should return same runner when runner is failed" do
      runner = %Runner{failed?: true, changes: %{status: :rejected}}
      predicate = fn _ -> true end
      func = fn runner -> %Runner{runner | changes: Map.put(runner.changes, :compensation, :done)} end
      assert %Runner{failed?: true, changes: %{status: :rejected}} == Runner.branch(runner, predicate, func)
    end
  end

  describe "switch/2" do
    test "should return updated runner when selector returns a continuation" do
      runner = %Runner{changes: %{status: :settled}}

      selector =
        fn
          %{status: :settled} -> &set_final_ok/1
          _ -> &set_final_error/1
        end

      assert %Runner{changes: changes} = Runner.switch(runner, selector)
      assert %{status: :settled, final: :ok} == changes
    end

    test "should return same runner when runner is failed" do
      runner = %Runner{failed?: true, changes: %{status: :settled}}
      selector = fn _ -> &set_final_ok/1 end
      assert %Runner{failed?: true, changes: %{status: :settled}} == Runner.switch(runner, selector)
    end

    defp set_final_ok(runner = %Runner{}),
      do: %Runner{runner | changes: Map.put(runner.changes, :final, :ok)}

    defp set_final_error(runner = %Runner{}),
      do: %Runner{runner | changes: Map.put(runner.changes, :final, :error)}
  end

  describe "finish/1" do
    test "should return {:ok, changes} when all steps succeed" do
      step_function = fn _changes -> {:ok, :result} end
      runner = %Runner{timeout: 100, steps: [{:sync, :step, step_function}]}
      assert {:ok, %{step: :result}} == Runner.finish(runner)
    end

    test "should return {:error, step, reason, changes_before} when step fails" do
      put_step = {:put, :value, 1}
      fail_function = fn _changes -> {:error, :boom} end
      runner = %Runner{timeout: 100, steps: [put_step, {:sync, :fail, fail_function}]}
      assert {:error, :fail, :boom, %{value: 1}} == Runner.finish(runner)
    end
  end

  describe "finish/2" do
    test "should return transformed result when all steps succeed" do
      step_function = fn _changes -> {:ok, :result} end
      finish_function = fn {:ok, changes} -> changes end
      runner = %Runner{timeout: 100, steps: [{:sync, :step, step_function}]}
      assert %{step: :result} == Runner.finish(runner, finish_function)
    end

    test "should return transformed error when any step fails" do
      fail_function = fn _changes -> {:error, :boom} end
      finish_function = fn {:error, step, reason, _changes_before} -> {:error, step, reason} end
      runner = %Runner{timeout: 100, steps: [{:sync, :fail, fail_function}]}
      assert {:error, :fail, :boom} == Runner.finish(runner, finish_function)
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

  defp assert_runner_result(runner_result, expected_result),
    do: assert(runner_result == expected_result)
end
