defmodule Commanded.Projections.Ecto do
  @moduledoc """
  Read model projections for [Commanded](https://hex.pm/packages/commanded) using Ecto.

  Example usage:

      defmodule Projector do
        use Commanded.Projections.Ecto,
          name: "my-projection",
          repo: MyRepo,
          schema_prefix: "my-prefix",
          timeout: :infinity

        project %Event{}, _metadata, fn multi ->
          Ecto.Multi.insert(multi, :my_projection, %MyProjection{...})
        end

        project %AnotherEvent{}, fn multi ->
          Ecto.Multi.insert(multi, :my_projection, %MyProjection{...})
        end
      end

  """

  defmacro __using__(opts) do
    opts = opts || []

    schema_prefix =
      opts[:schema_prefix] || Application.get_env(:commanded_ecto_projections, :schema_prefix)

    quote location: :keep do
      @opts unquote(opts)
      @repo @opts[:repo] || Application.get_env(:commanded_ecto_projections, :repo) ||
              raise("Commanded Ecto projections expects :repo to be configured in environment")
      @projection_name @opts[:name] || raise("#{inspect(__MODULE__)} expects :name to be given")
      @schema_prefix unquote(schema_prefix)
      @timeout @opts[:timeout] || :infinity

      # Pass through any other configuration to the event handler
      @handler_opts Keyword.drop(@opts, [:repo, :schema_prefix, :timeout])

      unquote do: Commanded.Projections.ProjectionVersion.__include__(prefix: schema_prefix)

      use Ecto.Schema
      use Commanded.Event.Handler, @handler_opts

      import Ecto.Changeset
      import Ecto.Query
      import unquote(__MODULE__)

      def update_projection(event, %{event_number: event_number} = metadata, multi_fn) do
        initial_multi = setup_transaction(event_number)

        with %Ecto.Multi{} = multi <- apply_projection_to_multi(initial_multi, multi_fn),
             {:noop?, false} <- {:noop?, multi == initial_multi},
             {:ok, changes} <- attempt_transaction(multi) do
          after_update(event, metadata, changes)
        else
          {:noop?, true} -> :ok # after_update(event, metadata, :noop)
          {:error, :verify_projection_version, :already_seen_event, _changes} -> :ok
          {:error, _stage, error, _changes} -> {:error, error}
          {:error, error} -> {:error, error}
        end
      end

      defp setup_transaction(event_number) do
        changeset =
          ProjectionVersion.changeset(
            %ProjectionVersion{projection_name: @projection_name},
            %{last_seen_event_number: event_number}
          )

        Ecto.Multi.new()
        |> Ecto.Multi.run(:verify_projection_version, &verify_projection_version(&1, &2, event_number))
        |> Ecto.Multi.update(:projection_version, changeset, prefix: unquote(schema_prefix))
      end

      defp verify_projection_version(_repo, _changes, event_number) do
        version =
          case @repo.get(ProjectionVersion, @projection_name) do
            nil ->
              @repo.insert!(%ProjectionVersion{
                projection_name: @projection_name,
                last_seen_event_number: 0
              })

            version ->
              version
          end

        if version.last_seen_event_number == nil ||
             version.last_seen_event_number < event_number do
          {:ok, %{version: version}}
        else
          {:error, :already_seen_event}
        end
      end

      def after_update(_event, _metadata, _changes), do: :ok

      defoverridable after_update: 3

      defp apply_projection_to_multi(%Ecto.Multi{} = multi, multi_fn)
           when is_function(multi_fn, 1) do
        try do
          apply(multi_fn, [multi])
        rescue
          e -> {:error, e}
        end
      end

      defp attempt_transaction(multi) do
        try do
          @repo.transaction(multi, timeout: @timeout, pool_timeout: @timeout)
        rescue
          e -> {:error, e}
        end
      end
    end
  end

  defmacro project(event, do: block) do
    IO.warn(
      "project macro with \"do end\" block is deprecated; use project/2 with function instead",
      Macro.Env.stacktrace(__ENV__)
    )

    quote do
      def handle(unquote(event) = event, metadata) do
        update_projection(event, metadata, fn var!(multi) ->
          unquote(block)
        end)
      end
    end
  end

  defmacro project(event, lambda) do
    quote do
      def handle(unquote(event) = event, metadata) do
        update_projection(event, metadata, unquote(lambda))
      end
    end
  end

  defmacro project(event, metadata, do: block) do
    IO.warn(
      "project macro with \"do end\" block is deprecated; use project/3 with function instead",
      Macro.Env.stacktrace(__ENV__)
    )

    quote do
      def handle(unquote(event) = event, unquote(metadata) = metadata) do
        update_projection(event, metadata, fn var!(multi) ->
          unquote(block)
        end)
      end
    end
  end

  defmacro project(event, metadata, lambda) do
    quote do
      def handle(unquote(event) = event, unquote(metadata) = metadata) do
        update_projection(event, metadata, unquote(lambda))
      end
    end
  end
end
