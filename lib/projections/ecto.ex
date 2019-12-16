defmodule Commanded.Projections.Ecto do
  @moduledoc """
  Read model projections for Commanded using Ecto.

  ## Example usage

      defmodule Projector do
        use Commanded.Projections.Ecto,
          application: MyApp.Application,
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

  ## Guides

  - [Getting started](getting-started.html)
  - [Usage](usage.html)

  """

  @callback after_update(event :: struct, metadata :: map, changes :: Ecto.Multi.changes()) ::
              :ok | {:error, any}

  @callback schema_prefix(event :: struct) :: String.t()

  @optional_callbacks [after_update: 3, schema_prefix: 1]

  defmacro __using__(opts) do
    opts = opts || []

    schema_prefix =
      opts[:schema_prefix] || Application.get_env(:commanded_ecto_projections, :schema_prefix)

    quote location: :keep do
      @behaviour Commanded.Projections.Ecto

      @opts unquote(opts)
      @repo @opts[:repo] || Application.get_env(:commanded_ecto_projections, :repo) ||
              raise("Commanded Ecto projections expects :repo to be configured in environment")
      @projection_name @opts[:name] || raise("#{inspect(__MODULE__)} expects :name to be given")
      @timeout @opts[:timeout] || :infinity

      # Pass through any other configuration to the event handler
      @handler_opts Keyword.drop(@opts, [:repo, :schema_prefix, :timeout])

      unquote(__include_schema_prefix__(schema_prefix))
      unquote(__include_projection_version_schema__())

      use Ecto.Schema
      use Commanded.Event.Handler, @handler_opts

      import Ecto.Changeset
      import Ecto.Query
      import unquote(__MODULE__)

      def update_projection(event, metadata, multi_fn) do
        %{event_number: event_number} = metadata

        changeset =
          ProjectionVersion.changeset(%ProjectionVersion{projection_name: @projection_name}, %{
            last_seen_event_number: event_number
          })

        prefix = schema_prefix(event)

        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.run(:verify_projection_version, fn repo, _changes ->
            version =
              case repo.get(ProjectionVersion, @projection_name, prefix: prefix) do
                nil ->
                  repo.insert!(
                    %ProjectionVersion{
                      projection_name: @projection_name,
                      last_seen_event_number: 0
                    },
                    prefix: prefix
                  )

                version ->
                  version
              end

            if is_nil(version.last_seen_event_number) ||
                 version.last_seen_event_number < event_number do
              {:ok, %{version: version}}
            else
              {:error, :already_seen_event}
            end
          end)
          |> Ecto.Multi.update(:projection_version, changeset, prefix: prefix)

        with %Ecto.Multi{} = multi <- apply_projection_to_multi(multi, multi_fn),
             {:ok, changes} <- attempt_transaction(multi) do
          if function_exported?(__MODULE__, :after_update, 3) do
            apply(__MODULE__, :after_update, [event, metadata, changes])
          else
            :ok
          end
        else
          {:error, :verify_projection_version, :already_seen_event, _changes} -> :ok
          {:error, _stage, error, _changes} -> {:error, error}
          {:error, error} -> {:error, error}
        end
      end

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

      defoverridable schema_prefix: 1
    end
  end

  defp __include_schema_prefix__(schema_prefix) do
    quote do
      cond do
        is_nil(unquote(schema_prefix)) ->
          def schema_prefix(_event), do: nil

        is_binary(unquote(schema_prefix)) ->
          def schema_prefix(_event), do: unquote(schema_prefix)

        is_function(unquote(schema_prefix), 1) ->
          def schema_prefix(event), do: apply(unquote(schema_prefix), [event])

        true ->
          raise ArgumentError,
            message:
              "expected :schema_prefix option to be a string or a one-arity function, but got: " <>
                inspect(unquote(schema_prefix))
      end
    end
  end

  defp __include_projection_version_schema__ do
    quote do
      defmodule ProjectionVersion do
        @moduledoc false

        use Ecto.Schema

        import Ecto.Changeset

        @primary_key {:projection_name, :string, []}

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
