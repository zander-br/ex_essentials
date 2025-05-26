defmodule Support.Validators.Types.User.Course do
  use Ecto.Schema

  import Ecto.Changeset

  @fields ~w(name duration level)a
  @levels ~w(beginner intermediary advanced)

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:duration, :integer)
    field(:level, :string)
  end

  def changeset(schema, params) do
    schema
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> validate_number(:duration, greater_than: 0)
    |> validate_inclusion(:level, @levels)
  end
end
