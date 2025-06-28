defmodule ExEssentials.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_essentials,
      version: "0.4.2",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ],
      description: description(),
      package: package(),
      name: "ExEssentials",
      source_url: "https://github.com/zander-br/ex_essentials",
      aliases: aliases()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, ">= 1.14.0 and <= 1.18.0"},
      {:ecto, "~> 3.10"},
      {:jason, "~> 1.4"},
      {:fun_with_flags, ">= 1.11.0 and <= 1.13.0", optional: true},
      {:saxy, ">= 1.5.0 and <= 1.6.0", optional: true},
      {:ecto_sql, "~> 3.4", optional: true},
      {:postgrex, ">= 0.0.0", optional: true},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:phoenix, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "ExEssentials is a powerful utility library for Elixir that serves as a true toolbox — bringing together a collection of generic, reusable, and ready-to-use helpers to accelerate Elixir application development."
  end

  defp package do
    [
      maintainers: ["Anderson Santos"],
      name: "ex_essentials",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/zander-br/ex_essentials"}
    ]
  end

  defp aliases do
    [
      test: ["ecto.drop --quiet", "ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
