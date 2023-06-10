defmodule Bling.Paddle.MixProject do
  use Mix.Project

  def project do
    [
      app: :bling_paddle,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Add recurring billing to your Phoenix application",
      package: [
        licenses: ["MIT"],
        links: %{
          "GitHub" => "https://github.com/ozziexsh/bling_paddle"
        },
        files: ~w(lib stubs mix.exs README.md .formatter.exs)
      ],
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

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
      {:ex_doc, "~> 0.29.4"},
      {:phoenix, "~> 1.7.2"},
      {:plug, "~> 1.14"},
      {:httpoison, "~> 2.0"},
      {:php_serializer, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.6"},
      {:postgrex, ">= 0.0.0", only: :test},
      {:faker, "~> 0.17", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
