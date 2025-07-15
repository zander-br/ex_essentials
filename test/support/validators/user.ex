defmodule Support.Validators.User do
  use Ecto.Schema

  import Ecto.Changeset

  alias Support.Validators.Types.User.Course
  alias Support.Validators.Types.User.Preferences
  alias __MODULE__

  @fields ~w(name email)a

  schema "users" do
    field :name, :string
    field :email, :string

    embeds_one :preferences, Preferences
    embeds_many :courses, Course
  end

  def create(params) do
    %User{}
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> cast_embed(:preferences, required: true)
    |> cast_embed(:courses, required: true)
  end
end
