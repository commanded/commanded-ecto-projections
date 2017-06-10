defmodule Commanded.Projections.Ecto do
  @moduledoc """
  Read model projections for Commanded using Ecto.

  Example usage:

      defmodule Projector do
        use Commanded.Projections.Ecto, name: "my-projection"

        project %Event{}, _metadata do
          Ecto.Multi.insert(multi, :my_projection, %MyProjection{...})
        end

        project %AnotherEvent{} do
          Ecto.Multi.insert(multi, :my_projection, %MyProjection{...})
        end
      end
  """

  defmacro __using__(name: name) do
    quote do
      use Ecto.Schema

      import Ecto.Changeset
      import Ecto.Query
      import unquote(__MODULE__)

      alias Commanded.Projections.ProjectionVersion

      @behaviour Commanded.Event.Handler

      @before_compile unquote(__MODULE__)

      @repo Application.get_env(:commanded_ecto_projections, :repo)
      @projection_name unquote(name)

      def update_projection(%{event_id: event_id}, multi_fn) do
        multi =
          Ecto.Multi.new
          |> Ecto.Multi.run(:verify_projection_version, fn _ ->
            version = case @repo.get(ProjectionVersion, @projection_name) do
              nil -> @repo.insert!(%ProjectionVersion{projection_name: @projection_name, last_seen_event_id: 0})
              version -> version
            end

            if version.last_seen_event_id == nil || version.last_seen_event_id < event_id do
              {:ok, %{version: version}}
            else
              {:error, :already_seen_event}
            end
          end)
          |> Ecto.Multi.update(:projection_version, ProjectionVersion.changeset(%ProjectionVersion{projection_name: @projection_name}, %{last_seen_event_id: event_id}))

        multi = apply(multi_fn, [multi])

        case @repo.transaction(multi, timeout: :infinity, pool_timeout: :infinity) do
          {:ok, _changes} -> :ok
          {:error, :verify_projection_version, :already_seen_event, _changes_so_far} -> :ok
          {:error, stage, reason, _changes_so_far} -> {:error, reason}
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # ignore all other events
      def handle(_event, _metadata), do: :ok
    end
  end

  defmacro project(event, metadata, do: block) do
    quote do
      def handle(unquote(event), unquote(metadata) = metadata) do
        update_projection(metadata, fn var!(multi) ->
          unquote(block)
        end)
      end
    end
  end

  defmacro project(event, do: block) do
    quote do
      def handle(unquote(event), metadata) do
        update_projection(metadata, fn var!(multi) ->
          unquote(block)
        end)
      end
    end
  end
end
