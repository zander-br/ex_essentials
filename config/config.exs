import Config

alias Ecto.Adapters.SQL.Sandbox
alias FunWithFlags.Store.Persistent.Ecto
alias Support.Repo

config :ex_essentials, ecto_repos: [Repo]

config :ex_essentials, Repo,
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  database: "ex_essentials_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Sandbox,
  pool_size: 10

config :ex_essentials, repo: Repo

config :fun_with_flags,
  persistence: [adapter: Ecto, repo: Repo],
  cache_bust_notifications: [enabled: false],
  cache: [enabled: false]

config :logger, level: :info
