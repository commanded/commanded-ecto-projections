defmodule Commanded.Projections.Ecto.Mixfile do
  use Mix.Project

  @version "1.2.0"

  def project do
    [
      app: :commanded_ecto_projections,
      version: @version,
      elixir: "~> 1.6",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      description: description(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:commanded, "~> 1.2"},
      {:ecto, "~> 3.4"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, ">= 0.0.0", only: :test},

      # Optional dependencies
      {:jason, "~> 1.2", optional: true},

      # Test & build tooling
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["ecto.create", "ecto.migrate"],
      reset: ["ecto.drop", "setup"]
    ]
  end

  defp description do
    """
    Read model projections for Commanded using Ecto.
    """
  end

  defp dialyzer do
    [
      plt_add_apps: [:ecto, :ex_unit],
      plt_add_deps: :app_tree,
      plt_file: {:no_warn, "priv/plts/commanded_ecto_projections.plt"}
    ]
  end

  defp docs do
    [
      main: "Commanded.Projections.Ecto",
      canonical: "http://hexdocs.pm/commanded_ecto_projections",
      source_ref: "v#{@version}",
      extra_section: "GUIDES",
      extras: [
        "CHANGELOG.md",
        "guides/Getting Started.md",
        "guides/Usage.md"
      ],
      groups_for_extras: [
        Introduction: [
          "guides/Getting Started.md",
          "guides/Usage.md"
        ]
      ]
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
        "GitHub" => "https://github.com/commanded/commanded-ecto-projections"
      }
    ]
  end
end
