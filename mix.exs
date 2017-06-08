defmodule Commanded.Projections.Ecto.Mixfile do
  use Mix.Project

  def project do
    [
      app: :commanded_ecto_projections,
      version: "0.1.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
    ]
  end

  def application do
    [
      extra_applications: [
        :logger,
      ],
    ]
  end

  defp deps do
    [
      {:ecto, "~> 2.1", runtime: false},
    ]
  end
end
