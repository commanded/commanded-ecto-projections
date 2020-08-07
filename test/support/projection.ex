defmodule Commanded.Projections.Projection do
  use Ecto.Schema

  schema "projections" do
    field(:name, :string)
  end
end
