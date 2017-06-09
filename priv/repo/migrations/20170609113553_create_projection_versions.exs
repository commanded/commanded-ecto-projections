defmodule Commanded.Projections.Repo.Migrations.CreateProjectionVersions do
  use Ecto.Migration

  def change do
    create table(:projection_versions, primary_key: false) do
      add :projection_name, :text, primary_key: true
      add :last_seen_event_id, :bigint

      timestamps()
    end
  end
end
