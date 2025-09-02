defmodule ExEssentials.BrazilianDocument.Formatter do
  @moduledoc """
    Provides formatting and masking for Brazilian CPF and CNPJ documents,
    including support for alphanumeric CNPJs.

    This module exposes functions to:

      * `format/1` — formats CPF and CNPJ numbers using the standard visual
        patterns used in Brazil.
      * `mask/1` — masks CPF and CNPJ numbers, hiding sensitive parts while
        keeping the standard visual notation.

    ## Examples

        iex> ExEssentials.BrazilianDocument.Formatter.format("39053344705")
        "390.533.447-05"

        iex> ExEssentials.BrazilianDocument.Formatter.format("11222333000181")
        "11.222.333/0001-81"

        iex> ExEssentials.BrazilianDocument.Formatter.format("AB123CD456EF01")
        nil

        iex> ExEssentials.BrazilianDocument.Formatter.mask("44286185060")
        "***.861.850-**"

        iex> ExEssentials.BrazilianDocument.Formatter.mask("63219659000153")
        "63.***.***/0001-5*"

    The `format/1` and `mask/1` functions detect the document type and
    delegate to the appropriate CPF or CNPJ implementation.
  """

  alias ExEssentials.BrazilianDocument.Validator

  @cpf_regex ~r/^(\d{3})(\d{3})(\d{3})(\d{2})$/
  @cnpj_regex ~r/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/
  @cnpj_alphanum_regex ~r/^([A-Z0-9]{2})([A-Z0-9]{3})([A-Z0-9]{3})([A-Z0-9]{4})(\d{2})$/
  @alphanum_regex ~r/[^a-zA-Z0-9]/

  @doc """
    Formats a string as either CPF or CNPJ depending on its length.
    It delegates to `cpf_format/1` or `cnpj_format/1` accordingly.

    ## Parameters
      - document: a string containing a CPF or CNPJ.

    ## Returns
      - A formatted document string if valid, otherwise `nil`.

    ## Examples
        iex> ExEssentials.BrazilianDocument.Formatter.format("44286185060")
        "442.861.850-60"

        iex> ExEssentials.BrazilianDocument.Formatter.format("63219659000153")
        "63.219.659/0001-53"

        iex> ExEssentials.BrazilianDocument.Formatter.format("12ABC34501DE38")
        nil
  """
  @spec format(document :: String.t()) :: String.t() | nil
  def format(document) when is_binary(document) do
    cleaned = String.trim(document)

    cond do
      String.length(cleaned) == 11 -> cpf_format(cleaned)
      String.length(cleaned) == 14 -> cnpj_format(cleaned)
      true -> nil
    end
  end

  @doc """
    Masks a string as either CPF or CNPJ depending on its length.
    It delegates to `cpf_mask/1` or `cnpj_mask/1` accordingly.

    ## Parameters
      - document: a string containing a CPF or CNPJ.

    ## Returns
      - A formatted document string if valid, otherwise `nil`.

    ## Examples
        iex> ExEssentials.BrazilianDocument.Formatter.mask("44286185060")
        "***.861.850-**"

        iex> ExEssentials.BrazilianDocument.Formatter.mask("63219659000153")
        "63.***.***/0001-5*"

        iex> ExEssentials.BrazilianDocument.Formatter.mask("12ABC34501DE38")
        nil
  """
  @spec mask(document :: String.t()) :: String.t() | nil
  def mask(document) when is_binary(document) do
    cleaned = String.trim(document)

    cond do
      String.length(cleaned) == 11 -> cpf_mask(cleaned)
      String.length(cleaned) == 14 -> cnpj_mask(cleaned)
      true -> nil
    end
  end

  @doc """
    Formats a CPF string with dots and dash.
    Only valid CPFs are formatted; otherwise, returns `nil`.

    ## Parameters
      - cpf: a string of 11 digits (formatted or not).

    ## Examples
        iex> ExEssentials.BrazilianDocument.Formatter.cpf_format("70694167096")
        "706.941.670-96"

        iex> ExEssentials.BrazilianDocument.Formatter.cpf_format("70694167099")
        nil
  """
  @spec cpf_format(cpf :: String.t()) :: String.t() | nil
  def cpf_format(cpf) when is_binary(cpf) do
    digits = cpf |> extract_numeric_digits() |> Enum.join()
    if Validator.cpf_valid?(digits), do: Regex.replace(@cpf_regex, digits, "\\1.\\2.\\3-\\4"), else: nil
  end

  @doc """
    Formats a CNPJ string using the standard Brazilian notation.
    Supports both numeric and alphanumeric CNPJs. Returns `nil` if the document is invalid.

    ## Parameters
      - cnpj: a numeric or alphanumeric CNPJ string.

    ## Examples
        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_format("20495056000171")
        "20.495.056/0001-71"

        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_format("12ABC34501DE35")
        "12.ABC.345/01DE-35"

        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_format("20495056000172")
        nil

        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_format("AB123CD456EF01")
        nil
  """
  @spec cnpj_format(cnpj :: String.t()) :: String.t() | nil
  def cnpj_format(cnpj) when is_binary(cnpj) do
    if Regex.match?(@cnpj_alphanum_regex, cnpj) do
      cnpj_alphanum_format(cnpj)
    else
      cnpj_numeric_format(cnpj)
    end
  end

  @doc """
    Masks a CPF string, hiding the first three and the last two digits,
    while keeping the middle six digits visible.
    Only valid CPFs are masked; otherwise, returns `nil`.

    ## Parameters
      - cpf: a string of 11 digits (formatted or not).

    ## Examples
        iex> ExEssentials.BrazilianDocument.Formatter.cpf_mask("70694167096")
        "***.941.670-**"

        iex> ExEssentials.BrazilianDocument.Formatter.cpf_mask("70694167099")
        nil
  """
  @spec cpf_mask(cpf :: String.t()) :: String.t() | nil
  def cpf_mask(cpf) when is_binary(cpf) do
    digits = cpf |> extract_numeric_digits() |> Enum.join()
    if Validator.cpf_valid?(digits), do: Regex.replace(@cpf_regex, digits, "***.\\2.\\3-**"), else: nil
  end

  @doc """
    Masks a CNPJ string by hiding the second and third digit groups with `***`,
    while keeping the first two digits and the branch (4th group) visible.
    The last two characters are partially masked, showing only the first and
    replacing the last one with `*`.

    Supports both numeric and alphanumeric CNPJs. Returns `nil` if the document is invalid.

    ## Parameters
      - cnpj: a numeric or alphanumeric CNPJ string.

    ## Examples
        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_mask("20495056000171")
        "20.***.***/0001-7*"

        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_mask("12ABC34501DE35")
        "12.***.***/01DE-3*"

        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_mask("20495056000172")
        nil

        iex> ExEssentials.BrazilianDocument.Formatter.cnpj_mask("AB123CD456EF01")
        nil
  """
  @spec cnpj_mask(cnpj :: String.t()) :: String.t() | nil
  def cnpj_mask(cnpj) when is_binary(cnpj) do
    if Regex.match?(@cnpj_alphanum_regex, cnpj) do
      cnpj_alphanum_mask(cnpj)
    else
      cnpj_numeric_mask(cnpj)
    end
  end

  defp cnpj_numeric_format(cnpj) when is_binary(cnpj) do
    digits = cnpj |> extract_numeric_digits() |> Enum.join()
    if Validator.cnpj_valid?(digits), do: Regex.replace(@cnpj_regex, digits, "\\1.\\2.\\3/\\4-\\5"), else: nil
  end

  defp cnpj_alphanum_format(cnpj) when is_binary(cnpj) do
    cleaned = cnpj |> String.replace(@alphanum_regex, "") |> String.upcase()

    if Validator.cnpj_valid?(cleaned),
      do: Regex.replace(@cnpj_alphanum_regex, cleaned, "\\1.\\2.\\3/\\4-\\5"),
      else: nil
  end

  defp cnpj_numeric_mask(cnpj) when is_binary(cnpj) do
    digits = cnpj |> extract_numeric_digits() |> Enum.join()

    if Validator.cnpj_valid?(digits) do
      @cnpj_regex
      |> Regex.replace(digits, "\\1.***.***/\\4-\\5")
      |> String.replace(~r/(\d)\z/, "*")
    else
      nil
    end
  end

  defp cnpj_alphanum_mask(cnpj) when is_binary(cnpj) do
    cleaned = cnpj |> String.replace(@alphanum_regex, "") |> String.upcase()

    if Validator.cnpj_valid?(cleaned) do
      @cnpj_alphanum_regex
      |> Regex.replace(cleaned, "\\1.***.***/\\4-\\5")
      |> String.replace(~r/(\d)\z/, "*")
    else
      nil
    end
  end

  defp extract_numeric_digits(doc) do
    doc
    |> String.replace(~r/[^0-9]/, "")
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
  end
end
