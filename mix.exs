defmodule Commanded.Projections.Ecto.Mixfile do
  use Mix.Project

  @version "0.8.0"

  def project do
    [
      app: :commanded_ecto_projections,
      version: @version,
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: extra_applications(Mix.env())
    ]
  end

  # Include ecto and postgrex apps in `test` environment only
  defp extra_applications(:test) do
    [:logger, :ecto, :ecto_sql, :postgrex]
  end

  defp extra_applications(_env) do
    [:logger]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:commanded, github: "commanded/commanded"},
      {:ecto, "~> 3.0", runtime: false},
      {:ecto_sql, "~> 3.0", runtime: false},
      {:postgrex, "~> 0.14", only: :test},

      # Optional dependencies
      {:jason, "~> 1.1", optional: true},

      # Test & build tooling
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:mix_test_watch, "~> 0.9", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Read model projections for Commanded using Ecto
    """
  end

  defp docs do
    [
      main: "Commanded.Projections.Ecto",
      canonical: "http://hexdocs.pm/commanded_ecto_projections",
      source_ref: "v#{@version}"
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        ".formatter.exs",
        "README*",
        "LICENSE*",
        "priv/repo/migrations"
      ],
      maintainers: ["Ben Smith"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/commanded/commanded-ecto-projections",
        "Docs" => "https://hexdocs.pm/commanded_ecto_projections/"
      }
    ]
  end
end
