defmodule ExEssentials.BrazilianDocument.ChangesetTest do
  use ExUnit.Case

  import ExEssentials.BrazilianDocument.Changeset

  defmodule Client do
    use Ecto.Schema

    import Ecto.Changeset

    @fields ~w(name document)a

    schema "clients" do
      field :name, :string
      field :document, :string
    end

    def changeset(attrs) do
      %Client{}
      |> cast(attrs, @fields)
      |> validate_required(@fields)
    end
  end

  describe "validate_brazilian_document/3" do
    setup do
      attrs = %{name: "John Doe", document: "52423987013"}
      %{attrs: attrs}
    end

    test "should return %Changeset{valid?: true} when given a valid CPF",
         %{attrs: attrs} do
      assert changeset = attrs |> Client.changeset() |> validate_brazilian_document(:document)
      assert changeset.valid?
    end

    test "should return %Changeset{valid?: true} when given a valid CNPJ",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "81415129000162")
      assert changeset = attrs |> Client.changeset() |> validate_brazilian_document(:document)
      assert changeset.valid?
    end

    test "should return %Changeset{valid?: true} when given a valid alphanumeric CNPJ",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12ABC34501DE35")
      assert changeset = attrs |> Client.changeset() |> validate_brazilian_document(:document)
      assert changeset.valid?
    end

    test "should return %Changeset{valid?: false} when given an invalid CPF",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12345678901")
      assert changeset = attrs |> Client.changeset() |> validate_brazilian_document(:document)
      refute changeset.valid?
      assert [document: {"is not a valid Brazilian document", []}] == changeset.errors
    end

    test "should return %Changeset{valid?: false} when given an invalid CNPJ",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "02345678000195")
      assert changeset = attrs |> Client.changeset() |> validate_brazilian_document(:document)
      refute changeset.valid?
      assert [document: {"is not a valid Brazilian document", []}] == changeset.errors
    end

    test "should return %Changeset{valid?: false} when given an invalid alphanumeric CNPJ",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12ABC34501DE38")
      assert changeset = attrs |> Client.changeset() |> validate_brazilian_document(:document)
      refute changeset.valid?
      assert [document: {"is not a valid Brazilian document", []}] == changeset.errors
    end

    test "should return %Changeset{valid?: false} when given an invalid document and custom message",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12345678901")
      opts = [message: "is invalid"]
      assert changeset = attrs |> Client.changeset() |> validate_brazilian_document(:document, opts)
      refute changeset.valid?
      assert [document: {"is invalid", []}] == changeset.errors
    end
  end

  describe "validate_cnpj/3" do
    setup do
      attrs = %{name: "John Doe", document: "81415129000162"}
      %{attrs: attrs}
    end

    test "should return %Changeset{valid?: true} when given a valid CNPJ",
         %{attrs: attrs} do
      assert changeset = attrs |> Client.changeset() |> validate_cnpj(:document)
      assert changeset.valid?
    end

    test "should return %Changeset{valid?: true} when given a valid alphanumeric CNPJ",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12ABC34501DE35")
      assert changeset = attrs |> Client.changeset() |> validate_cnpj(:document)
      assert changeset.valid?
    end

    test "should return %Changeset{valid?: false} when given an invalid CNPJ",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "02345678000195")
      assert changeset = attrs |> Client.changeset() |> validate_cnpj(:document)
      refute changeset.valid?
      assert [document: {"is not a valid CNPJ", []}] == changeset.errors
    end

    test "should return %Changeset{valid?: false} when given an invalid alphanumeric CNPJ",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12ABC34501DE38")
      assert changeset = attrs |> Client.changeset() |> validate_cnpj(:document)
      refute changeset.valid?
      assert [document: {"is not a valid CNPJ", []}] == changeset.errors
    end

    test "should return %Changeset{valid?: false} when given an invalid document and custom message",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "02345678000195")
      opts = [message: "is invalid"]
      assert changeset = attrs |> Client.changeset() |> validate_cnpj(:document, opts)
      refute changeset.valid?
      assert [document: {"is invalid", []}] == changeset.errors
    end
  end

  describe "validate_cpf/3" do
    setup do
      attrs = %{name: "John Doe", document: "52423987013"}
      %{attrs: attrs}
    end

    test "should return %Changeset{valid?: true} when given a valid CPF",
         %{attrs: attrs} do
      assert changeset = attrs |> Client.changeset() |> validate_cpf(:document)
      assert changeset.valid?
    end

    test "should return %Changeset{valid?: false} when given an invalid CPF",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12345678901")
      assert changeset = attrs |> Client.changeset() |> validate_cpf(:document)
      refute changeset.valid?
      assert [document: {"is not a valid CPF", []}] == changeset.errors
    end

    test "should return %Changeset{valid?: false} when given an invalid document and custom message",
         %{attrs: attrs} do
      attrs = Map.put(attrs, :document, "12345678901")
      opts = [message: "is invalid"]
      assert changeset = attrs |> Client.changeset() |> validate_cpf(:document, opts)
      refute changeset.valid?
      assert [document: {"is invalid", []}] == changeset.errors
    end
  end
end
