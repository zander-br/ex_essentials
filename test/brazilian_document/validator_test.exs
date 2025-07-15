defmodule ExEssentials.BrazilianDocument.ValidatorTest do
  use ExUnit.Case

  doctest ExEssentials.BrazilianDocument.Validator

  alias ExEssentials.BrazilianDocument.Validator

  describe "valid?/1" do
    test "should return true for valid CPF",
      do: assert(Validator.valid?("52423987013"))

    test "should return true for valid CPF numbers that start with zero",
      do: assert(Validator.valid?("04337459081"))

    test "should return true for a valid CPF that starts with two zeros",
      do: assert(Validator.valid?("00408719915"))

    test "should return true for a valid CPF that starts with three zeros",
      do: assert(Validator.valid?("00036580589"))

    test "should return true for valid CNPJ",
      do: assert(Validator.valid?("81415129000162"))

    test "should return true for valid CNPJ numbers that start with zero",
      do: assert(Validator.valid?("07205272000177"))

    test "should return true for valid CNPJ that starts with two zeros",
      do: assert(Validator.valid?("00895553000150"))

    test "should return true for valid CNPJ that starts with three zeros",
      do: assert(Validator.valid?("00028986000108"))

    test "should return true for valid alphanumeric CNPJ",
      do: assert(Validator.valid?("12ABC34501DE35"))

    test "should return false for invalid CPF",
      do: refute(Validator.valid?("12345678901"))

    test "should return false for invalid CNPJ",
      do: refute(Validator.valid?("02345678000195"))

    test "should return false for invalid document length",
      do: refute(Validator.valid?("1234567890"))

    test "should return false for invalid alphanumeric CNPJ",
      do: refute(Validator.valid?("12ABC34501DE38"))
  end

  describe "cnpj_valid?/1" do
    test "should return true for valid CNPJ",
      do: assert(Validator.cnpj_valid?("81415129000162"))

    test "should return true for valid alphanumeric CNPJ",
      do: assert(Validator.cnpj_valid?("12ABC34501DE35"))

    test "should return false for invalid CNPJ",
      do: refute(Validator.cnpj_valid?("02345678000195"))
  end

  describe "cpf_valid?/1" do
    test "should return true for valid CPF",
      do: assert(Validator.cpf_valid?("52423987013"))

    test "should return false for invalid CPF",
      do: refute(Validator.cpf_valid?("12345678901"))
  end
end
