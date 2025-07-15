defmodule Support.Validators.Types.User.Preferences do
  use Ecto.Schema

  import Ecto.Changeset

  @themes ~w(light dark)
  @languages ~w(en pt-br)
  @fields ~w(theme language)a

  @primary_key false
  embedded_schema do
    field :theme, :string
    field :language, :string
  end

  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> validate_inclusion(:theme, @themes)
    |> validate_inclusion(:language, @languages)
  end
end
