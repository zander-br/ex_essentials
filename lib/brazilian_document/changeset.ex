defmodule ExEssentials.BrazilianDocument.Changeset do
  @moduledoc """
    Provides Ecto.Changeset validators for Brazilian CPF and CNPJ documents.

    This module offers three helper functions to easily validate fields within an Ecto changeset:
    - `validate_brazilian_document/3`: Automatically detects whether the field contains a CPF or CNPJ.
    - `validate_cpf/3`: Specifically validates CPF numbers.
    - `validate_cnpj/3`: Specifically validates CNPJ numbers.

    ## Examples
        import Ecto.Changeset

        alias ExEssentials.BrazilianDocument.Changeset

        changeset =
          %User{}
          |> cast(%{"cpf" => "39053344705"}, [:cpf])
          |> Changeset.validate_cpf(:cpf)

        changeset.valid?
        #=> true
  """

  alias Ecto.Changeset
  alias ExEssentials.BrazilianDocument.Validator

  @doc """
    Validates a field as either CPF or CNPJ, depending on the value.
    Uses `ExEssentials.BrazilianDocument.Validator.valid?/1` under the hood.

    ## Parameters
      - changeset: an `Ecto.Changeset` struct.
      - field: the atom representing the field name.
      - opts: an optional keyword list. Accepts `:message` to override the default error message.

    ## Examples
        iex> validate_brazilian_document(changeset, :document)
        iex> validate_brazilian_document(changeset, :document, message: "is invalid")
  """
  @spec validate_brazilian_document(changeset :: Changeset.t(), field :: atom(), opts :: keyword()) :: Changeset.t()
  def validate_brazilian_document(changeset, field, opts \\ []) when is_atom(field) do
    Changeset.validate_change(changeset, field, fn _, value ->
      if Validator.valid?(value) do
        []
      else
        message = Keyword.get(opts, :message, "is not a valid Brazilian document")
        [{field, message}]
      end
    end)
  end

  @doc """
    Validates a field as a valid CNPJ (Cadastro Nacional da Pessoa Jurídica).

    ## Parameters
      - changeset: an `Ecto.Changeset` struct.
      - field: the atom representing the field name.
      - opts: an optional keyword list. Accepts `:message` to override the default error message.

    ## Examples
        iex> validate_cnpj(changeset, :company_cnpj)
        iex> validate_cnpj(changeset, :company_cnpj, message: "is invalid")
  """
  @spec validate_cnpj(changeset :: Changeset.t(), field :: atom(), opts :: keyword()) :: Changeset.t()
  def validate_cnpj(changeset, field, opts \\ []) when is_atom(field) do
    Changeset.validate_change(changeset, field, fn _, value ->
      if Validator.cnpj_valid?(value) do
        []
      else
        message = Keyword.get(opts, :message, "is not a valid CNPJ")
        [{field, message}]
      end
    end)
  end

  @doc """
    Validates a field as a valid CPF (Cadastro de Pessoas Físicas).

    ## Parameters
      - changeset: an `Ecto.Changeset` struct.
      - field: the atom representing the field name.
      - opts: an optional keyword list. Accepts `:message` to override the default error message.

    ## Examples
        iex> validate_cpf(changeset, :cpf)
        iex> validate_cpf(changeset, :cpf, message: "is invalid")
  """
  @spec validate_cpf(changeset :: Changeset.t(), field :: atom(), opts :: keyword()) :: Changeset.t()
  def validate_cpf(changeset, field, opts \\ []) when is_atom(field) do
    Changeset.validate_change(changeset, field, fn _, value ->
      if Validator.cpf_valid?(value) do
        []
      else
        message = Keyword.get(opts, :message, "is not a valid CPF")
        [{field, message}]
      end
    end)
  end
end
