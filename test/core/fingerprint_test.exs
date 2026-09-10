defmodule ExEssentials.Core.FingerprintTest do
  use ExUnit.Case, async: true

  doctest ExEssentials.Core.Fingerprint

  alias ExEssentials.Core.Fingerprint

  describe "hash/2" do
    test "should return hex hash string when data and keys are given" do
      data = %{name: "Alice", age: 31}
      keys = [:name, :age]
      expected_hash = "5051f3cb3674dcc04d817eeaa8b2cc0c6620ed52a29a9063258a557e354cbffb"
      assert expected_hash == Fingerprint.hash(data, keys)
    end
  end

  describe "equal?/3" do
    test "should return true when values for specified keys match" do
      a = %{id: 1, name: "Bob", role: :admin}
      b = %{id: 1, name: "Bob", role: :user}
      keys = [:id, :name]
      assert Fingerprint.equal?(a, b, keys)
    end

    test "should return false when values for specified keys differ" do
      a = %{id: 1, name: "Bob", role: :admin}
      b = %{id: 1, name: "Bob", role: :user}
      keys = [:id, :role]
      refute Fingerprint.equal?(a, b, keys)
    end
  end
end
