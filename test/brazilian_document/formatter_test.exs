defmodule ExEssentials.BrazilianDocument.FormatterTest do
  use ExUnit.Case

  doctest ExEssentials.BrazilianDocument.Formatter

  alias ExEssentials.BrazilianDocument.Formatter

  describe "format/1" do
    test "should return formatted CPF when given a valid CPF" do
      valid_cpf = "52423987013"
      assert "524.239.870-13" == Formatter.format(valid_cpf)
    end

    test "should return formatted CPF when given a valid CPF that start with zero" do
      valid_cpf = "04337459081"
      assert "043.374.590-81" == Formatter.format(valid_cpf)
    end

    test "should return formatted CPF when given a valid CPF that starts with two zeros" do
      valid_cpf = "00408719915"
      assert "004.087.199-15" == Formatter.format(valid_cpf)
    end

    test "should return formatted CPF when given a valid CPF that start with three zeros" do
      valid_cpf = "00036580589"
      assert "000.365.805-89" == Formatter.format(valid_cpf)
    end

    test "should return formatted CNPJ when given a valid CNPJ" do
      valid_cnpj = "81415129000162"
      assert "81.415.129/0001-62" == Formatter.format(valid_cnpj)
    end

    test "should return formatted CNPJ when given a valid CNPJ that start with zero" do
      valid_cnpj = "07205272000177"
      assert "07.205.272/0001-77" == Formatter.format(valid_cnpj)
    end

    test "should return formatted CNPJ when given a valid CNPJ that starts with two zeros" do
      valid_cnpj = "00895553000150"
      assert "00.895.553/0001-50" == Formatter.format(valid_cnpj)
    end

    test "should return formatted CNPJ when given a valid CNPJ that start with three zeros" do
      valid_cnpj = "00028986000108"
      assert "00.028.986/0001-08" == Formatter.format(valid_cnpj)
    end

    test "should return formatted alphanumeric CNPJ when given a valid alphanumeric CNPJ" do
      valid_cnpj = "12ABC34501DE35"
      assert "12.ABC.345/01DE-35" == Formatter.format(valid_cnpj)
    end

    test "should return nil for invalid document length" do
      invalid_document = "1234567890"
      assert nil == Formatter.format(invalid_document)
    end
  end

  describe "mask/1" do
    test "should return masked CPF when given a valid CPF" do
      valid_cpf = "52423987013"
      assert "***.239.870-**" == Formatter.mask(valid_cpf)
    end

    test "should return masked CPF when given a valid CPF that start with zero" do
      valid_cpf = "04337459081"
      assert "***.374.590-**" == Formatter.mask(valid_cpf)
    end

    test "should return masked CPF when given a valid CPF that starts with two zeros" do
      valid_cpf = "00408719915"
      assert "***.087.199-**" == Formatter.mask(valid_cpf)
    end

    test "should return masked CPF when given a valid CPF that start with three zeros" do
      valid_cpf = "00036580589"
      assert "***.365.805-**" == Formatter.mask(valid_cpf)
    end

    test "should return masked CNPJ when given a valid CNPJ" do
      valid_cnpj = "81415129000162"
      assert "81.***.***/0001-6*" == Formatter.mask(valid_cnpj)
    end

    test "should return masked CNPJ when given a valid CNPJ that start with zero" do
      valid_cnpj = "07205272000177"
      assert "07.***.***/0001-7*" == Formatter.mask(valid_cnpj)
    end

    test "should return masked CNPJ when given a valid CNPJ that starts with two zeros" do
      valid_cnpj = "00895553000150"
      assert "00.***.***/0001-5*" == Formatter.mask(valid_cnpj)
    end

    test "should return masked CNPJ when given a valid CNPJ that start with three zeros" do
      valid_cnpj = "00028986000108"
      assert "00.***.***/0001-0*" == Formatter.mask(valid_cnpj)
    end

    test "should return masked alphanumeric CNPJ when given a valid alphanumeric CNPJ" do
      valid_cnpj = "12ABC34501DE35"
      assert "12.***.***/01DE-3*" == Formatter.mask(valid_cnpj)
    end

    test "should return nil for invalid document length" do
      invalid_document = "1234567890"
      assert nil == Formatter.mask(invalid_document)
    end
  end

  describe "cpf_format/1" do
    test "should return formatted CPF when given a valid CPF" do
      valid_cpf = "52423987013"
      assert "524.239.870-13" == Formatter.cpf_format(valid_cpf)
    end

    test "should return nil when given an invalid CPF" do
      invalid_cpf = "12345678901"
      assert nil == Formatter.cpf_format(invalid_cpf)
    end
  end

  describe "cnpj_format/1" do
    test "should return formatted CNPJ when given a valid CNPJ" do
      valid_cnpj = "81415129000162"
      assert "81.415.129/0001-62" == Formatter.cnpj_format(valid_cnpj)
    end

    test "should return formatted alphanumeric CNPJ when given a valid alphanumeric CNPJ" do
      valid_cnpj = "12ABC34501DE35"
      assert "12.ABC.345/01DE-35" == Formatter.cnpj_format(valid_cnpj)
    end

    test "should return nil when given an invalid CNPJ" do
      invalid_cnpj = "02345678000195"
      assert nil == Formatter.cnpj_format(invalid_cnpj)
    end
  end

  describe "cpf_mask/1" do
    test "should return masked CPF when given a valid CPF" do
      valid_cpf = "52423987013"
      assert "***.239.870-**" == Formatter.cpf_mask(valid_cpf)
    end

    test "should return nil when given an invalid CPF" do
      invalid_cpf = "12345678901"
      assert nil == Formatter.cpf_mask(invalid_cpf)
    end
  end

  describe "cnpj_mask/1" do
    test "should return masked CNPJ when given a valid CNPJ" do
      valid_cnpj = "81415129000162"
      assert "81.***.***/0001-6*" == Formatter.cnpj_mask(valid_cnpj)
    end

    test "should return masked alphanumeric CNPJ when given a valid alphanumeric CNPJ" do
      valid_cnpj = "12ABC34501DE35"
      assert "12.***.***/01DE-3*" == Formatter.cnpj_mask(valid_cnpj)
    end

    test "should return nil when given an invalid CNPJ" do
      invalid_cnpj = "02345678000195"
      assert nil == Formatter.cnpj_mask(invalid_cnpj)
    end
  end
end
