# Getting started

You should already have [Ecto](https://github.com/elixir-ecto/ecto) installed and configured before proceeding. Please follow Ecto's [Getting Started](https://hexdocs.pm/ecto/getting-started.html) guide to get going first.

1. Add `:commanded_ecto_projections` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {:commanded_ecto_projections, "~> 1.2"}
      ]
    end
    ```

2. Generate an Ecto migration in your app:

    ```console
    $ mix ecto.gen.migration create_projection_versions
    ```

3. Modify the generated migration, in `priv/repo/migrations`, to create the `projection_versions` table:

    ```elixir
    defmodule CreateProjectionVersions do
      use Ecto.Migration

      def change do
        create table(:projection_versions, primary_key: false) do
          add(:projection_name, :text, primary_key: true)
          add(:last_seen_event_number, :bigint)

          timestamps(type: :naive_datetime_usec)
        end
      end
    end
    ```

5. Run the Ecto migration:

    ```console
    $ mix ecto.migrate
    ```

6. Define your first read model projector:

    ```elixir
    defmodule MyApp.ExampleProjector do
      use Commanded.Projections.Ecto,
        application: MyApp.Application,
        repo: MyApp.Projections.Repo,
        name: "example_projection"
    end
    ```

Refer to the Usage guide for more detail on how to configure and use a read model projector.
