alias Commanded.Projections.Repo

{:ok, _} = Repo.start_link()

defmodule CreateProjections do
  use Ecto.Migration

  def change do
    create table(:projections) do
      add :name, :text
    end
  end
end

Ecto.Migrator.up(Repo, 20170609120000, CreateProjections)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
