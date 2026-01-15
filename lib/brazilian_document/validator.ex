defmodule ExEssentials.BrazilianDocument.Validator do
  @moduledoc """
    Provides validation for Brazilian CPF and CNPJ documents, including support for alphanumeric CNPJs.
    This module can be used to validate individual CPF or CNPJ numbers, with or without formatting characters.

    ## Examples
        iex> ExEssentials.BrazilianDocument.Validator.valid?("26944480000132")
        true

        iex> ExEssentials.BrazilianDocument.Validator.valid?("26944480000132")
        true

        iex> ExEssentials.BrazilianDocument.Validator.valid?("12ABC34501DE35")
        true

        iex> ExEssentials.BrazilianDocument.Validator.valid?("48335092029")
        false

        iex> ExEssentials.BrazilianDocument.Validator.valid?("26944480000133")
        false

        iex> ExEssentials.BrazilianDocument.Validator.valid?("AB123CD456EF01")
        false

    The `valid?/1` function will automatically detect whether the given document is a CPF or CNPJ based on its length.
  """
  @first_weights_cnpj [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  @second_weights_cnpj [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
  @first_weights_cpf [10, 9, 8, 7, 6, 5, 4, 3, 2]
  @second_weights_cpf [11, 10, 9, 8, 7, 6, 5, 4, 3, 2]
  @alphanum_regex ~r/[^a-zA-Z0-9]/
  @cnpj_alphanum_regex ~r/^([A-Z0-9]{2})([A-Z0-9]{3})([A-Z0-9]{3})([A-Z0-9]{4})(\d{2})$/

  @doc """
    Determines if a given string is a valid CPF or CNPJ.
    It strips whitespace and delegates to the appropriate validation function based on document length.

    ## Parameters
      - document: a string containing a CPF or CNPJ, with or without formatting.

    ## Examples

        iex> ExEssentials.BrazilianDocument.Validator.valid?("16664593051")
        false

        iex> ExEssentials.BrazilianDocument.Validator.valid?("16664593050")
        true

    Returns `true` if valid, `false` if invalid.
  """
  @spec valid?(document :: String.t()) :: boolean()
  def valid?(document) do
    input = normalize_input(document)

    case document_type(input) do
      :cnpj_alphanum -> input |> clean_alphanum() |> cnpj_valid?()
      :cpf -> input |> clean_digits() |> cpf_valid?()
      :cnpj -> input |> clean_digits() |> cnpj_valid?()
      :invalid -> false
    end
  end

  @doc """
    Validates a CNPJ (Cadastro Nacional da Pessoa Jurídica), including support for alphanumeric formats.
    It detects if the CNPJ is numeric or alphanumeric and applies the appropriate validation rules.

    ## Parameters
      - cnpj: a string containing a numeric or alphanumeric CNPJ.

    ## Examples
        iex> ExEssentials.BrazilianDocument.Validator.cnpj_valid?("78944804000136")
        true

        iex> ExEssentials.BrazilianDocument.Validator.cnpj_valid?("12ABC34501DE35")
        true

        iex> ExEssentials.BrazilianDocument.Validator.cnpj_valid?("78944804000137")
        false

        iex> ExEssentials.BrazilianDocument.Validator.cnpj_valid?("12ABC34501DE36")
        false
  """
  @spec cnpj_valid?(cnpj :: String.t()) :: boolean()
  def cnpj_valid?(cnpj) when is_binary(cnpj) do
    if Regex.match?(@cnpj_alphanum_regex, cnpj) do
      cnpj_alphanum_valid?(cnpj)
    else
      cnpj_numeric_valid?(cnpj)
    end
  end

  @doc """
    Validates a CPF (Cadastro de Pessoas Físicas).
    The function extracts numeric digits, verifies check digits, and checks against known invalid repeated values.

    ## Parameters
      - cpf: a string containing a CPF, formatted or not.

    ## Examples

        iex> ExEssentials.BrazilianDocument.Validator.cpf_valid?("05859468092")
        false

        iex> ExEssentials.BrazilianDocument.Validator.cpf_valid?("05859468091")
        true
  """
  @spec cpf_valid?(cpf :: String.t()) :: boolean()
  def cpf_valid?(cpf) when is_binary(cpf) do
    with digits when length(digits) == 11 <- extract_numeric_digits(cpf),
         false <- repeated_digits?(digits) do
      base = Enum.slice(digits, 0..8)
      digits == append_cpf_digits(base)
    else
      _ -> false
    end
  end

  defp normalize_input(document) when is_binary(document),
    do: document |> String.trim() |> String.upcase()

  defp clean_alphanum(input) when is_binary(input),
    do: String.replace(input, @alphanum_regex, "")

  defp clean_digits(input) when is_binary(input),
    do: String.replace(input, ~r/[^0-9]/, "")

  defp document_type(input) when is_binary(input) do
    alphanum = clean_alphanum(input)
    clean_digits = clean_digits(input)

    cond do
      Regex.match?(@cnpj_alphanum_regex, alphanum) -> :cnpj_alphanum
      String.length(clean_digits) == 11 -> :cpf
      String.length(clean_digits) == 14 -> :cnpj
      true -> :invalid
    end
  end

  defp cnpj_numeric_valid?(cnpj) when is_binary(cnpj) do
    with digits when length(digits) == 14 <- extract_numeric_digits(cnpj),
         false <- repeated_digits?(digits) do
      base = Enum.slice(digits, 0..11)
      digits == append_cnpj_digits(base)
    else
      _ -> false
    end
  end

  defp cnpj_alphanum_valid?(cnpj) when is_binary(cnpj) do
    cleaned = cnpj |> String.replace(@alphanum_regex, "") |> String.upcase()

    with {base, dv} <- String.split_at(cleaned, 12),
         true <- byte_size(base) == 12 and byte_size(dv) == 2,
         graphemes = String.graphemes(base),
         false <- repeated_chars?(graphemes),
         true <- valid_alphanum_chars?(graphemes),
         dv1 <- calculate_dv(graphemes, @first_weights_cnpj),
         dv2 <- calculate_dv(graphemes ++ [Integer.to_string(dv1)], @second_weights_cnpj) do
      "#{dv1}#{dv2}" == dv
    else
      _ -> false
    end
  end

  defp calculate_dv(chars, weights) do
    values = Enum.map(chars, &to_numeric_value/1)
    sum = values |> Enum.zip(weights) |> Enum.map(&product_of_pair/1) |> Enum.sum()
    rem = rem(sum, 11)
    if rem < 2, do: 0, else: 11 - rem
  end

  defp product_of_pair({value, weight}), do: value * weight

  defp to_numeric_value(<<char::utf8>>), do: char - ?0
  defp to_numeric_value(int) when is_integer(int), do: int

  defp append_cnpj_digits(base) do
    d1 = calculate_dv(base, @first_weights_cnpj)
    d2 = calculate_dv(base ++ [d1], @second_weights_cnpj)
    base ++ [d1, d2]
  end

  defp append_cpf_digits(base) do
    d1 = calculate_dv(base, @first_weights_cpf)
    d2 = calculate_dv(base ++ [d1], @second_weights_cpf)
    base ++ [d1, d2]
  end

  defp extract_numeric_digits(doc) do
    doc
    |> String.replace(~r/[^0-9]/, "")
    |> String.graphemes()
    |> Enum.map(&String.to_integer/1)
  end

  defp repeated_digits?([]), do: false
  defp repeated_digits?(digits), do: Enum.uniq(digits) == [hd(digits)]

  defp repeated_chars?([]), do: false
  defp repeated_chars?(chars), do: Enum.uniq(chars) == [hd(chars)]

  defp valid_alphanum_chars?(chars),
    do: Enum.all?(chars, fn <<char::utf8>> -> char in ?0..?9 or char in ?A..?Z end)
end
