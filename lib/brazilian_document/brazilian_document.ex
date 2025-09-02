defmodule ExEssentials.BrazilianDocument do
  @moduledoc """
    Convenience module for validating, formatting, and masking Brazilian CPF and CNPJ documents.

    This module delegates functionality to the appropriate modules:
      - `ExEssentials.BrazilianDocument.Validator` for validation
      - `ExEssentials.BrazilianDocument.Formatter` for formatting and masking

    Use this module when you want a simplified interface for handling CPF and CNPJ
    without needing to reference specific modules.

    ## Examples

        iex> ExEssentials.BrazilianDocument.valid?("09340933001")
        true

        iex> ExEssentials.BrazilianDocument.cnpj_valid?("09281987000134")
        true

        iex> ExEssentials.BrazilianDocument.format("76713868045")
        "767.138.680-45"

        iex> ExEssentials.BrazilianDocument.cnpj_format("87671632000165")
        "87.671.632/0001-65"

        iex> ExEssentials.BrazilianDocument.mask("44286185060")
        "***.861.850-**"

        iex> ExEssentials.BrazilianDocument.mask("63219659000153")
        "63.***.***/0001-5*"
  """

  alias ExEssentials.BrazilianDocument.Formatter
  alias ExEssentials.BrazilianDocument.Validator

  @spec format(document :: String.t()) :: String.t() | nil
  defdelegate format(document), to: Formatter

  @spec mask(document :: String.t()) :: String.t() | nil
  defdelegate mask(document), to: Formatter

  @spec cpf_format(cpf :: String.t()) :: String.t() | nil
  defdelegate cpf_format(cpf), to: Formatter

  @spec cnpj_format(cnpj :: String.t()) :: String.t() | nil
  defdelegate cnpj_format(cnpj), to: Formatter

  @spec cpf_mask(cpf :: String.t()) :: String.t() | nil
  defdelegate cpf_mask(cpf), to: Formatter

  @spec cnpj_mask(cnpj :: String.t()) :: String.t() | nil
  defdelegate cnpj_mask(cnpj), to: Formatter

  @spec valid?(document :: String.t()) :: boolean()
  defdelegate valid?(document), to: Validator

  @spec cnpj_valid?(cnpj :: String.t()) :: boolean()
  defdelegate cnpj_valid?(cnpj), to: Validator

  @spec cpf_valid?(cpf :: String.t()) :: boolean()
  defdelegate cpf_valid?(cpf), to: Validator
end
