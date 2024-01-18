import Config

config :commanded_ecto_projections,
  ecto_repos: [Commanded.Projections.Repo],
  repo: Commanded.Projections.Repo

config :commanded_ecto_projections, Commanded.Projections.Repo,
  database: "commanded_ecto_projections_test",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

config :ex_unit, capture_log: true

# Print only warning and above log messages during tests
config :logger, :console, level: :warning, format: "[$level] $message\n"
