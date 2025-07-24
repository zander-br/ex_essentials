defmodule ExEssentials.Core.MapTest do
  use ExUnit.Case

  doctest ExEssentials.Core.Map

  alias ExEssentials.Core.Map, as: ExtendedMap

  describe "renake/2" do
    setup do
      original_map = %{
        "name" => "Joe Doe",
        age: 35,
        contact: "joe.doe@mail.com",
        city: "São Paulo",
        role: :admin
      }

      %{original_map: original_map}
    end

    test "should return selected keys without renaming when only atoms are passed",
         %{original_map: original_map} do
      keys = [:age, :role]
      assert %{role: :admin, age: 35} == ExtendedMap.renake(original_map, keys)
    end

    test "should return selected keys with renaming when atom and tuple keys are passed",
         %{original_map: original_map} do
      keys = [:age, {:contact, :emal}]
      assert %{age: 35, emal: "joe.doe@mail.com"} == ExtendedMap.renake(original_map, keys)
    end

    test "should return selected and renamed keys when keys are atoms, tuples, and string keys",
         %{original_map: original_map} do
      keys = [:age, {"name", :name}, {:contact, :email}, :role]

      assert %{
               age: 35,
               email: "joe.doe@mail.com",
               name: "Joe Doe",
               role: :admin
             } == ExtendedMap.renake(original_map, keys)
    end
  end

  describe "renake/3" do
    setup do
      original_map = %{
        "name" => "Joe Doe",
        age: 35,
        contact: "joe.doe@mail.com",
        city: "São Paulo",
        role: :admin
      }

      %{original_map: original_map}
    end

    test "should return transformed values for selected keys when only atoms are passed",
         %{original_map: original_map} do
      keys = [:age, :role]
      assert %{role: "admin", age: 35} == ExtendedMap.renake(original_map, keys, &atom_to_string/1)
    end

    test "should return transformed values with renaming when atom and tuple keys are passed",
         %{original_map: original_map} do
      keys = [:age, {:contact, :emal}]
      assert %{age: 35, emal: "joe.doe@mail.com"} == ExtendedMap.renake(original_map, keys, &atom_to_string/1)
    end

    test "should return transformed and renamed values when keys are atoms, tuples, and string keys",
         %{original_map: original_map} do
      keys = [:age, {"name", :name}, {:contact, :email}, :role]

      assert %{
               age: 35,
               email: "joe.doe@mail.com",
               name: "Joe Doe",
               role: "admin"
             } == ExtendedMap.renake(original_map, keys, &atom_to_string/1)
    end
  end

  defp atom_to_string({_field, value}) when is_atom(value), do: Atom.to_string(value)
  defp atom_to_string({_field, value}), do: value
end
