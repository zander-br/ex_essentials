defmodule ExEssentials.DataCase do
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Support.Repo

  using do
    quote do
      alias Support.Repo

      import Ecto
      import Ecto.Query
      import ExEssentials.DataCase
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Repo)
    unless tags[:async], do: Sandbox.mode(Repo, {:shared, self()})
    :ok
  end
end
