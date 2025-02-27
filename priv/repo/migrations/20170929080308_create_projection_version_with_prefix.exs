defmodule Commanded.Projections.Repo.Migrations.CreateProjectionVersionWithPrefix do
  use Ecto.Migration

  def up do
    execute("CREATE SCHEMA test")

    create table(:projection_versions, primary_key: false, prefix: "test") do
      add(:projection_name, :text, primary_key: true)
      add(:last_seen_event_number, :bigint)

      timestamps(type: :timestamptz)
    end
  end

  def down do
    drop(table(:projection_versions, prefix: "test"))

    execute("DROP SCHEMA test CASCADE")
  end
end
