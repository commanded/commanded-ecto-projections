defmodule Commanded.Projections.Ecto.Mixfile do
  use Mix.Project

  @source_url "https://github.com/commanded/commanded-ecto-projections"
  @version "1.3.0"

  def project do
    [
      app: :commanded_ecto_projections,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer()
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
      {:ecto, "~> 3.5"},
      {:ecto_sql, "~> 3.5"},
      {:postgrex, ">= 0.0.0", only: :test},

      # Optional dependencies
      {:jason, "~> 1.3", optional: true},

      # Test & build tooling
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["ecto.create", "ecto.migrate"],
      reset: ["ecto.drop", "setup"]
    ]
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
      ],
      main: "Commanded.Projections.Ecto",
      canonical: "http://hexdocs.pm/commanded_ecto_projections",
      source_url: @source_url,
      source_ref: "v#{@version}",
      formatters: ["html"]
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
        "CHANGELOG*",
        "priv/repo/migrations"
      ],
      description: "Read model projections for Commanded using Ecto.",
      maintainers: ["Ben Smith"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/commanded/commanded-ecto-projections"
      }
    ]
  end
end
