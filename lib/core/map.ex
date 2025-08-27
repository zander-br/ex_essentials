defmodule ExEssentials.Core.Map do
  @moduledoc """
    A collection of utility functions for working with maps.

    This module provides tools to:
      - Rename or extract specific keys from a map.
      - Remove entries with `nil` or empty values (`""`, `[]`, `%{}`).

    Common use cases include transforming map structures and cleaning up payloads
    before encoding or external communication.
  """

  @doc """
    Renames and/or filters keys from a map, preserving only the specified keys.
    Keys can be passed as atoms (no renaming) or as `{from, to}` tuples for renaming.

    ## Examples

        iex> map = %{name: "Alice", age: 30, email: "alice@example.com"}
        iex> ExEssentials.Core.Map.renake(map, [:name, age: :years])
        %{name: "Alice", years: 30}
  """
  def renake(map, keys) when is_map(map) and is_list(keys),
    do: renake(map, keys, fn {_field, value} -> value end)

  @doc """
    Like `renake/2`, but applies a transformation function to each value before inserting it into the resulting map.

    ## Examples

        iex> map = %{price: 100, discount: 10}
        iex> ExEssentials.Core.Map.renake(map, [:price, discount: :off], fn {_field, value} -> value * 2 end)
        %{price: 200, off: 20}
  """
  def renake(map, keys, transform_fn) when is_map(map) and is_list(keys),
    do: Enum.reduce(keys, %{}, &rename_key(&1, &2, map, transform_fn))

  @doc """
    Removes all key-value pairs where the value is `nil`.

    ## Examples

        iex> map = %{a: 1, b: nil, c: "text"}
        iex> ExEssentials.Core.Map.compact_nil(map)
        %{a: 1, c: "text"}
  """
  def compact_nil(map) when is_map(map) do
    map
    |> Enum.reject(&nil_value?/1)
    |> Enum.into(%{})
  end

  @doc """
    Removes all key-value pairs where the value is considered "blank".
    A blank value is one of: `""`, `[]`, `%{}`.

    ## Examples

        iex> map = %{a: "", b: [], c: %{}, d: 42}
        iex> ExEssentials.Core.Map.compact_blank(map)
        %{d: 42}
  """
  def compact_blank(map) when is_map(map) do
    map
    |> Enum.reject(&blank?/1)
    |> Enum.into(%{})
  end

  @doc """
    Removes all key-value pairs where the value is either `nil`, `""`, `[]`, or `%{}`.

    ## Examples

        iex> map = %{a: nil, b: "", c: [], d: %{}, e: "keep"}
        iex> ExEssentials.Core.Map.compact(map)
        %{e: "keep"}
  """
  def compact(map) when is_map(map) do
    map
    |> Enum.reject(&empty_value?/1)
    |> Enum.into(%{})
  end

  defp rename_key({from, to}, renamed_map, original_map, transform_fn) do
    case Map.get(original_map, from) do
      nil ->
        Map.put(renamed_map, to, nil)

      value ->
        transformed_value = transform_fn.({to, value})
        Map.put(renamed_map, to, transformed_value)
    end
  end

  defp rename_key(key, renamed_map, original_map, transform_fn) do
    case Map.get(original_map, key) do
      nil ->
        Map.put(renamed_map, key, nil)

      value ->
        transformed_value = transform_fn.({key, value})
        Map.put(renamed_map, key, transformed_value)
    end
  end

  defp nil_value?({_key, value}), do: is_nil(value)

  defp blank?({_key, value}), do: value in ["", [], %{}]

  defp empty_value?({_key, value}), do: value in [nil, "", [], %{}]
end
