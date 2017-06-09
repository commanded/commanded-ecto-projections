defmodule Commanded.Projections.Ecto.Mixfile do
  use Mix.Project

  def project do
    [
      app: :commanded_ecto_projections,
      version: "0.1.0",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env),
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env),
    ]
  end

  # include ecto and postgrex apps in `test` environment only
  defp extra_applications(:test) do
    [
      :logger,
      :ecto,
      :postgrex,
    ]
  end
  defp extra_applications(_) do
    [
      :logger,
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, "~> 2.1", runtime: false},
      {:postgrex, "~> 0.13", only: :test},
      {:mix_test_watch, "~> 0.4", only: :dev, runtime: false},
    ]
  end

  defp description do
"""
Read model projections for Commanded using Ecto
"""
end

defp package do
  [
    files: [
      "lib", "mix.exs", "README*", "LICENSE*",
      "priv/repo/migrations",
    ],
    maintainers: ["Ben Smith"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/slashdotdash/commanded-ecto-projections",
             "Docs" => "https://hexdocs.pm/commanded_ecto_projections/"}
  ]
end
end
