defmodule ExEssentials.Web.Plugs.NormalizeQueryParams do
  @moduledoc """
  A plug that normalizes query parameters by converting special string values
  into their literal Elixir equivalents.

  ## Normalizations applied:

    * "\"\"" → ""
    * "null" / "undefined" → nil
    * "[]" → []
    * "{}" → %{}
    * "true" / "false" → true / false
    * Numeric strings like "123" → 123 (integer)
    * Decimal strings like "1.23" → 1.23 (float)
    * CSV strings like "open,closed" → ["open", "closed"]
    * Map-like strings like "{key: value}" → %{"key" => "value"}

  ## Usage

  This plug should be placed in your Phoenix `endpoint.ex` before `Plug.Parsers`
  to ensure it only affects query parameters, and not body parameters.

      plug ExEssentials.Web.Plugs.NormalizeQueryParams

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Jason

  With the plug enabled, incoming query parameters like:

      /example?status="null"&ids=1,2,3&filters={type: admin, active: true}

  Will be transformed into:

      %{
        "status" => nil,
        "ids" => [1, 2, 3],
        "filters" => %{"type" => "admin", "active" => true}
      }
  """

  alias Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    %Conn{body_params: body_params, query_params: query_params} = conn
    query_params = normalize(query_params)
    params = Map.merge(body_params, query_params)
    %Conn{conn | query_params: query_params, params: params}
  end

  defp normalize(%{} = map), do: for({key, value} <- map, into: %{}, do: {key, normalize(value)})
  defp normalize([head | tail]), do: [normalize(head) | normalize(tail)]
  defp normalize([]), do: []

  defp normalize(str) when is_binary(str) do
    str
    |> normalize_empty()
    |> normalize_null()
    |> normalize_boolean()
    |> normalize_special_structures()
    |> normalize_number()
    |> normalize_map_like_structure()
    |> normalize_list_like_structure()
    |> normalize_csv_list()
  end

  defp normalize(other), do: other

  defp normalize_empty("\"\""), do: ""
  defp normalize_empty(""), do: ""
  defp normalize_empty(value), do: value

  defp normalize_null("null"), do: nil
  defp normalize_null("undefined"), do: nil
  defp normalize_null(value), do: value

  defp normalize_boolean("true"), do: true
  defp normalize_boolean("false"), do: false
  defp normalize_boolean(value), do: value

  defp normalize_special_structures("[]"), do: []
  defp normalize_special_structures("{}"), do: %{}
  defp normalize_special_structures(value), do: value

  defp normalize_number(value) when is_binary(value) do
    cond do
      Regex.match?(~r/^[-+]?\d+$/, value) -> String.to_integer(value)
      Regex.match?(~r/^[-+]?\d+\.\d+$/, value) -> String.to_float(value)
      true -> value
    end
  end

  defp normalize_number(value), do: value

  defp normalize_map_like_structure("{" <> rest = original) do
    if String.ends_with?(rest, "}") do
      rest
      |> String.trim_trailing("}")
      |> String.split(~r/, ?/)
      |> Enum.map(&parse_key_value_pair/1)
      |> Enum.into(%{})
    else
      original
    end
  end

  defp normalize_map_like_structure(value), do: value

  defp normalize_list_like_structure("[" <> rest = original) do
    if String.ends_with?(rest, "]") do
      rest
      |> String.trim_trailing("]")
      |> String.split(~r/, ?/, trim: true)
      |> Enum.map(&normalize/1)
    else
      original
    end
  end

  defp normalize_list_like_structure(value), do: value

  defp normalize_csv_list(str) when is_binary(str) do
    if String.contains?(str, ",") do
      str
      |> String.split(",", trim: true)
      |> Enum.map(&normalize/1)
    else
      str
    end
  end

  defp normalize_csv_list(value), do: value

  defp parse_key_value_pair(pair) do
    case String.split(pair, ":", parts: 2) do
      [key, value] -> {String.trim(key), value |> String.trim() |> normalize()}
      _ -> {pair, pair}
    end
  end
end
