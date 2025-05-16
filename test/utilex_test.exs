defmodule UtilexTest do
  use ExUnit.Case
  doctest Utilex

  test "greets the world" do
    assert Utilex.hello() == :world
  end
end
