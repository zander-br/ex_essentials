defmodule Support.Application do
  use Application

  @impl true
  def start(_type, _args) do
    env = Mix.env()

    if env == :test || env == :dev do
      children = [Support.Repo]
      opts = [strategy: :one_for_one, name: ExEssentials.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
end
