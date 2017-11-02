# Commanded Ecto projections

Read model projections for [Commanded](https://github.com/commanded/commanded) CQRS/ES applications using [Ecto](https://github.com/elixir-ecto/ecto) for persistence.

---

[Changelog](CHANGELOG.md)

MIT License

[![Build Status](https://travis-ci.org/commanded/commanded-ecto-projections.svg?branch=master)](https://travis-ci.org/commanded/commanded-ecto-projections)

---

### Overview

- [Getting started](#getting-started)
  - [Schema Prefix](#schema-prefix)
- [Usage](#usage)
  - [Supervision](#supervision)
  - [`after_update` callback](#after_update-callback)
  - [Rebuilding a projection](#rebuilding-a-projection)
- [Contributing](#contributing)
- [Need help?](#need-help)

## Getting started

You should already have [Ecto](https://github.com/elixir-ecto/ecto) installed and configured before proceeding. Please follow the Ecto [Getting Started](https://hexdocs.pm/ecto/getting-started.html) guide to get going first.

1. Add `commanded_ecto_projections` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {:commanded_ecto_projections, "~> 0.5"},
      ]
    end
    ```

2. Configure `commanded_ecto_projections` with the Ecto repo used by your application:

    ```elixir
    config :commanded_ecto_projections,
      repo: MyApp.Projections.Repo
    ```

    Or alternatively in case of umbrella application define it later per projection:

    ```elixir
    defmodule MyApp.ExampleProjector do
      use Commanded.Projections.Ecto,
        name: "example_projection",
        repo: MyApp.Projections.Repo

      ...
    end
    ```

3. Generate an Ecto migration in your app:

    ```console
    $ mix ecto.gen.migration create_projection_versions
    ```

4. Modify the generated migration, in `priv/repo/migrations`, to create the `projection_versions` table:

    ```elixir
    defmodule CreateProjectionVersions do
      use Ecto.Migration

      def change do
        create table(:projection_versions, primary_key: false) do
          add :projection_name, :text, primary_key: true
          add :last_seen_event_number, :bigint

          timestamps()
        end
      end
    end
    ```

4. Run the Ecto migration:

    ```console
    $ mix ecto.migrate
    ```

### Schema Prefix

When using a prefix for your schemas you might also want to change the prefix
for the `ProjectionVersion` schema. There are two options to do this:

1. provide a global prefix via the config

```elixir
config :commanded_ecto_projections,
  schema_prefix: "example_schema_prefix"
```

2. provide the prefix on a projection by projection basis

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto,
    name: "example_projection",
    schema_prefix: "example_schema_prefix"
end
```

## Usage

Use Ecto schemas to define your read model:

```elixir
defmodule ExampleProjection do
  use Ecto.Schema

  schema "example_projections" do
    field :name, :string
  end
end
```

For each read model you will need to define a module that uses the `Commanded.Projections.Ecto` macro and configures the domain events to be projected. The `:name` option passed to the `use` invocation specifies the name of the subscription to be used. It can be any string that is unique among subscriptions.

The `project/2` macro expects the domain event and metadata. You can also use `project/1` if you do not need to use the event metadata. Inside the project block you have access to an [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html) data structure, available as the `multi` variable, for grouping multiple Repo operations. These will all be executed within a single transaction. You can use `Ecto.Multi` to insert, update, and delete data.

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto, name: "example_projection"

  project %AnEvent{name: name}, _metadata do
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end

  project %AnotherEvent{name: name} do
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end
end
```

If you want to skip a projection event, you can return the `multi` transaction without further modifying it:

```elixir
project %ItemUpdated{uuid: uuid} = event, _metadata do
  case Repo.get(ItemProjection, uuid) do
    nil -> multi
    item -> Ecto.Multi.update(multi, :item, update_changeset(event, item))
  end
end
```

### Supervision

Your projector module must be included in your application supervision tree:

```elixir
defmodule MyApp.Projections.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(_) do
    children = [
      # projections
      worker(MyApp.ExampleProjector, [], id: :example_projector),
    ]

    supervise(children, strategy: :one_for_one)
  end
end
```

### `after_update` callback

You can define an `after_update/3` function in a projector to be called after each projected event. It receives the event, its associated metadata, and all changes from `Ecto.Multi` executed in the database transaction.

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto, name: "example_projection"

  project %AnEvent{name: name} do
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end

  def after_update(event, metadata, changes) do
    # ... use event, metadata, or `Ecto.Multi` changes
    :ok
  end
end
```

You could use this function to notify subscribers that the read model has been updated (e.g. pub/sub to Phoenix channels).

### Rebuilding a projection

The `projection_versions` table is used to ensure that events are only projected once.

To rebuild a projection you will need to:

1. Delete the row containing the last seen event for the projection name:

    ```SQL
    delete from projection_versions
    where projection_name = 'example_projection';
    ```

2. Truncate the tables that are being populated by the projection, and restart their identity:

    ```SQL
    truncate table
      example_projections,
      other_projections
    restart identity;
    ```

You will also need to reset the event store subscription for the commanded event handler. This is specific to whichever event store you are using.

### Contributing

Pull requests to contribute new or improved features, and extend documentation are most welcome. Please follow the existing coding conventions.

You should include unit tests to cover any changes. Run `mix test` to execute the test suite:

```console
mix deps.get
MIX_ENV=test mix do ecto.create, ecto.migrate
mix test
```

### Contributors

- [Andrey Akulov](https://github.com/astery)
- [Ben Smith](https://github.com/slashdotdash)
- [Florian Ebeling](https://github.com/febeling)
- [Sascha Wolf](https://github.com/Zeeker)

## Need help?

Please [open an issue](https://github.com/commanded/commanded-ecto-projections/issues) if you encounter a problem, or need assistance. You can also seek help in the [Gitter chat room](https://gitter.im/commanded/Lobby) for Commanded.

For commercial support, and consultancy, please contact [Ben Smith](mailto:ben@10consulting.com).
