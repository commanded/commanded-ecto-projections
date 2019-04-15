defmodule Commanded.Projections.ProjectionVersion do
  @moduledoc false

  def __include__(opts \\ []) do
    prefix = Keyword.get(opts, :prefix)

    quote do
      defmodule ProjectionVersion do
        @moduledoc false

        use Ecto.Schema

        import Ecto.Changeset

        @primary_key {:projection_name, :string, []}
        @schema_prefix unquote(prefix)

        schema "projection_versions" do
          field(:last_seen_event_number, :integer)

          timestamps(type: :naive_datetime_usec)
        end

        @required_fields ~w(last_seen_event_number)a

        def changeset(model, params \\ :invalid) do
          cast(model, params, @required_fields)
        end
      end
    end
  end
end
