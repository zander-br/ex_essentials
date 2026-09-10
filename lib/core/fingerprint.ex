defmodule ExEssentials.Core.Fingerprint do
  @moduledoc """
  Utilities for generating deterministic hashes (fingerprints) and comparing maps or structs based on selected keys.

  `ExEssentials.Core.Fingerprint` extracts specific keys from a map or struct, formats their values,
  and hashes them using SHA-256 to generate a consistent hex-encoded fingerprint representation.

  This is useful for:

    * Detecting payload changes across requests
    * Comparing subset attributes of structs or maps for equality
    * Generating cache keys or unique identifiers based on specific fields

  ## Examples

  ### Computing a fingerprint hash

      user = %{id: 1, name: "Alice", email: "alice@example.com"}
      ExEssentials.Core.Fingerprint.hash(user, [:id, :email])

  ### Comparing two structures by specific keys

      user_a = %{id: 1, name: "Alice", role: :admin}
      user_b = %{id: 1, name: "Alice", role: :user}

      ExEssentials.Core.Fingerprint.equal?(user_a, user_b, [:id, :name])
      #=> true

      ExEssentials.Core.Fingerprint.equal?(user_a, user_b, [:id, :role])
      #=> false

  """

  @doc """
  Compares two maps or structs for equality based on the specified keys.

  Calculates the SHA-256 fingerprint hash for both `left` and `right` using `keys`,
  and returns `true` if they are identical, or `false` otherwise.

  ## Examples

      iex> user_a = %{id: 42, name: "Joe"}
      iex> user_b = %{id: 42, name: "Joe", age: 30}
      iex> ExEssentials.Core.Fingerprint.equal?(user_a, user_b, [:id, :name])
      true
      iex> ExEssentials.Core.Fingerprint.equal?(user_a, user_b, [:id, :age])
      false

  """
  @spec equal?(left :: map() | struct(), right :: map() | struct(), keys :: list(atom())) ::
          boolean()
  def equal?(left, right, keys),
    do: hash(left, keys) == hash(right, keys)

  @doc """
  Generates a SHA-256 fingerprint hash for a map or struct based on the given keys.

  Values associated with `keys` are extracted in order, converted to strings, concatenated with `"&"`,
  and hashed into a lowercase hex string.

  ## Examples

      iex> ExEssentials.Core.Fingerprint.hash(%{a: "hello", b: "world"}, [:a, :b])
      "60c4a2ca447b1da45e2bf854d117faabda9a47a5656b8cfadc558cb61621eb78"

  """
  @spec hash(data :: map() | struct(), keys :: list(atom())) :: String.t()
  def hash(data, keys) do
    data
    |> values_from(keys)
    |> Enum.map_join("&", &to_string/1)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp values_from(data, keys),
    do: Enum.map(keys, &Map.get(data, &1))
end
