defmodule Commanded.Projections.ProjectionVersion do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:projection_name, :string, []}

  schema "projection_versions" do
    field :last_seen_event_id, :integer

    timestamps()
  end

  @required_fields ~w(last_seen_event_id)

  def changeset(model, params \\ :empty) do
    cast(model, params, @required_fields)
  end
end
