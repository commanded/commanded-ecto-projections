# Usage

## Creating a read model

Use `Ecto.Schema` to define one or more read models:

```elixir
defmodule ExampleProjection do
  use Ecto.Schema

  schema "example_projections" do
    field(:name, :string)
  end
end
```

## Creating a projector

For each read model you will need to define a module that uses the `Commanded.Projections.Ecto` module and projects the appropriate domain events with the `project` macro.

You must specify the following options when defining or starting an Ecto projector:

- `:application` - (module or atom) the Commanded application (e.g. `MyApp.Application`).
- `:name` - (string) a unique name used to identify the event store subscription used by the projector.
- `:repo` - (module) an Ecto repo (e.g. `MyApp.Projections.Repo`).

Once a projector has been deployed you _should not_ change its name. Doing so will cause a new event store subscription to be created and replay all existing events.

**Note:** A read model projector is just a specialised Commanded event handler `GenServer` process.

### Example

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto,
    application: MyApp.Application,
    repo: MyApp.Projections.Repo,
    name: "example_projection"

  project %AnEvent{name: name}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end

  project %AnotherEvent{name: name}, fn multi ->
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end
end
```

#### Runtime configuration

The `:application` and `:name` options can be provided at runtime, but `:repo` must be specified at compile-time.

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto,
    repo: MyApp.Projections.Repo
end
```

Started with:

```elixir
{:ok, pid} = ExampleProjector.start_link(application: MyApp.Application, name: "example_projection")
```

Or supervised:

```elixir
Supervisor.start_link([
  {ExampleProjector, application: MyApp.Application, name: "example_projection"}
], strategy: :one_for_one)
```

Runtime configuration allows the same projector to be run more than once, with each instance using a separate application or name:

```elixir
Supervisor.start_link([
  {ExampleProjector, application: App1, name: "App1.Projector"},
  {ExampleProjector, application: App2, name: "App2.Projector"}
], strategy: :one_for_one)
```

### Using the `project` macro

The `project/3` macro expects the domain event, metadata, and a single-arity function that takes and returns an `Ecto.Multi` data structure for grouping multiple Repo operations. These will all be executed within a single transaction. You can use `Ecto.Multi` to insert, update, and delete data.

#### Examples

Project an event and its metadata into a read model with `project/3`:

```elixir
project %AnEvent{name: name}, metadata, fn multi ->
  projection = %ExampleProjection{name: name, metadata: metadata}

  Ecto.Multi.insert(multi, :example_projection, projection)
end
```

Use `project/2` if you do not need to use the event metadata:

```elixir
project %AnotherEvent{name: name}, fn multi ->
  Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
end
```

If you want to skip a projection event, you can return the `multi` transaction without further modifying it:

```elixir
project %ItemUpdated{uuid: uuid} = event, _metadata, fn multi ->
  case Repo.get(ItemProjection, uuid) do
    nil -> multi
    item -> Ecto.Multi.update(multi, :item, update_changeset(event, item))
  end
end
```


### Using the `project_batch` macro

You can use `project_batch` to receive events in batches. To enable batching, you need to set the `batch_size` and use the `project_batch/2` macro. `project_batch/2` receives a list of `{event, metadata}` tuples for all the events in the batch and a similar single-arity function as `project/3` to affect an `Ecto.Multi` structure.

Note that there is currently no built in way to target a single type of event to be projected, and as such a single `project_batch` macro is expected to gracefully handle (or ignore) any events that it may receive

#### Example
```elixir
defmodule MyApp.Projections.BatchProjector do
  use Commanded.Projections.Ecto,
      application: MyApp.Application,
      repo: MyApp.Projections.Repo,
      name: "example_batch_projection",
      batch_size: 10

    project_batch events, fn multi ->
      projections = events
      |> Enum.map(fn
        {%AnEvent{name: name}, _metadata} -> %{name: name}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

      Ecto.Multi.insert_all(multi, :example_batch_projection, Projection, projections)
    end
end
```

## Supervision

Your projector module must be included in your application supervision tree:

```elixir
defmodule MyApp.Projections.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      MyApp.ExampleProjector
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

**Warning:** You should implement an [error handling](#error-handling) strategy in your projector module when supervising to prevent problematic events from causing cascading errors due too many restarts.

## Error handling

### `error/3` callback

The `Commanded.Projections.Ecto` macro defines a Commanded event handler which means you can take advantage of the [`error/3` callback function](https://hexdocs.pm/commanded/Commanded.Event.Handler.html#module-error-3-callback) to handle any errors returned from a `project` function. The error function is passed the error returned by the event handler (e.g. `{:error, error}`), the event causing the error, and a context map containing state passed between retries. Use the context map to track any transient state you need to access between retried failures, such as the number of failed attempts.

You can return one of the following responses depending upon the error severity:

- `{:retry, context}` - retry the failed event, provide a context map containing any state passed to subsequent failures. This could be used to count the number of failures, stopping after too many.

- `{:retry, delay, context}` - retry the failed event, after sleeping for the requested delay (in milliseconds). Context is a map as described in `{:retry, context}` above.

- `:skip` - skip the failed event by acknowledging receipt.

- `{:stop, reason}` - stop the projector with the given reason.

#### Error handling example

Here's an example projector module where an error tagged tuple is explicitly returned from a `project` function, but you can also handle exceptions caused by faulty `Ecto.Multi` database operations in a similar manner since the errors are caught and returned as tagged tuples (e.g. `{:error, %Ecto.ConstraintError{}}`).

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto,
    application: MyApp.Application,
    repo: MyApp.Projections.Repo,
    name: "MyApp.ExampleProjector"

  require Logger

  alias Commanded.Event.FailureContext

  project %AnEvent{}, fn _multi ->
    {:error, :failed}
  end

  def error({:error, :failed}, %AnEvent{}, %FailureContext{}) do
    :skip
  end

  def error({:error, %Ecto.ConstraintError{} = error}, _event, _failure_context) do
    Logger.error("Failed due to constraint error: " <> inspect(error))

    :skip
  end

  def error({:error, _error}, _event, _failure_context) do
    :skip
  end
end
```

### `after_update/3` callback

You can define an `after_update/3` callback function in a projector to be called after each projected event. The function receives the event, its metadata, and all changes from the `Ecto.Multi` struct that were executed within the database transaction.

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto,
    application: MyApp.Application,
    repo: MyApp.Projections.Repo,
    name: "MyApp.ExampleProjector"

  project %AnEvent{name: name}, fn multi ->
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end

  @impl Commanded.Projections.Ecto
  def after_update(event, metadata, changes) do
    # Use the event, metadata, or `Ecto.Multi` changes and return `:ok`
    :ok
  end
end
```

You could use this function to notify subscribers that the read model has been updated (e.g. pub/sub to Phoenix channels).

### `after_update_batch/2` callback

Similarly for batching projectors, you can define an `after_update_batch/2` callback function in a projector to be called after a batch of events has been projected. The functions receives a list of `{event, metadata}` tuples for each processed event and all changes from the `Ecto.Multi` struct


## Schema prefix

When using a prefix for your Ecto schemas you might also want to change the prefix for the `ProjectionVersion` schema. There are a number of options to do this:

1. Define a global static prefix via environment config:

    ```elixir
    # config/config.exs
    config :commanded_ecto_projections, schema_prefix: "example_schema_prefix"
    ```

2. Provide a static `schema_prefix` as a projector option:

    ```elixir
    defmodule MyApp.ExampleProjector do
      use Commanded.Projections.Ecto,
        application: MyApp.Application,
        repo: MyApp.Projections.Repo,
        name: "example_projection",
        schema_prefix: "example_schema_prefix"
    end
    ```

3. Provide a one-arity function as a `schema_prefix` projector option:

    ```elixir
    defmodule MyApp.ExampleProjector do
      use Commanded.Projections.Ecto,
        application: MyApp.Application,
        repo: MyApp.Projections.Repo,
        name: "example_projection",
        schema_prefix: fn event -> "example_schema_prefix" end
    end
    ```

    The function will receive the event as the single argument allowing you to use the same or a different schema for each event.

4. Provide a two-arity function as a `schema_prefix` projector option:

    ```elixir
    defmodule MyApp.ExampleProjector do
      use Commanded.Projections.Ecto,
        application: MyApp.Application,
        repo: MyApp.Projections.Repo,
        name: "example_projection",
        schema_prefix: fn event, metadata -> "example_schema_prefix" end
    end
    ```

    The function will receive the event and its associated metadata as the two arguments allowing you to use the same or a different schema for each event. The metadata will also include the enriched fields such as the application, event handler name, and optional handler state.

5. Define a `schema_prefix/1` callback function:

    ```elixir
    defmodule MyApp.ExampleProjector do
      use Commanded.Projections.Ecto,
        application: MyApp.Application,
        name: "example_projection"

      @impl Commanded.Projections.Ecto
      def schema_prefix(event), do: "example_schema_prefix"
    end
    ```

    The function will receive the event as the single argument allowing you to use the same or a different schema for each event.

    An example usage could be for tenant specific projections where each tenant's data is projected and stored in a separate database schema:

    ```elixir
    @impl Commanded.Projections.Ecto
    def schema_prefix(%_{tenant: tenant}), do: tenant
    ```

6. Define a `schema_prefix/2` callback function:

    ```elixir
    defmodule MyApp.ExampleProjector do
      use Commanded.Projections.Ecto,
        application: MyApp.Application,
        name: "example_projection"

      @impl Commanded.Projections.Ecto
      def schema_prefix(event, metadata), do: "example_schema_prefix"
    end
    ```

    The function will receive the event and its associated metadata as the two arguments allowing you to use the same or a different schema for each event. The metadata will also include the enriched fields such as the application, event handler name, and optional handler state.

    An example usage could be for tenant specific projections where each tenant's data is projected and stored in a separate database schema:

    ```elixir
    @impl Commanded.Projections.Ecto
    def schema_prefix(%_{tenant: tenant}, _metadata), do: tenant
    ```

### Migrations with a schema prefix

1. Generate an Ecto migration in your app:

    ```shell
    mix ecto.gen.migration create_schema_projection_versions
    ```

2. Modify the generated migration, in `priv/repo/migrations`, to create the schema and a `projection_versions` table for the schema:

    ```elixir
    defmodule CreateSchemaProjectionVersions do
      use Ecto.Migration

      def up do
        execute("CREATE SCHEMA example_schema_prefix")

        create table(:projection_versions, primary_key: false, prefix: "example_schema_prefix") do
          add(:projection_name, :text, primary_key: true)
          add(:last_seen_event_number, :bigint)

          timestamps(type: :naive_datetime_usec)
        end
      end

      def down do
        drop(table(:projection_versions, prefix: "example_schema_prefix"))

        execute("DROP SCHEMA example_schema_prefix CASCADE")
      end
    end
    ```

    Note you will need to do this for each schema prefix you use.

## Rebuilding a projection

The `projection_versions` table is used to ensure that events are only projected once.

To rebuild a projection you will need to:

1. Delete the row containing the last seen event for the projection name:

    ```SQL
    DELETE FROM projection_versions
    WHERE projection_name = 'example_projection';
    ```

2. Truncate the tables that are being populated by the projection, and restart their identity:

    ```SQL
    TRUNCATE TABLE
      example_projections,
      other_projections
    RESTART IDENTITY;
    ```

You will also need to reset the event store subscription for the commanded event handler. This is specific to whichever event store you are using.
