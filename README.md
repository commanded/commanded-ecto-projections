# Commanded Ecto projections

Read model projections for [Commanded](https://github.com/slashdotdash/commanded) CQRS/ES applications using [Ecto](https://github.com/elixir-ecto/ecto) for persistence.

## Installation

You should already have [Ecto](https://github.com/elixir-ecto/ecto) installed and configured before proceeding. Please follow the Ecto [Getting Started](https://hexdocs.pm/ecto/getting-started.html) guide to get going first.

1. Add `commanded_ecto_projections` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [
        {:commanded_ecto_projections, github: "slashdotdash/commanded-ecto-projections"},
      ]
    end
    ```

2. Configure `commanded_ecto_projections` with the Ecto repo used by your application:

    ```elixir
    config :commanded_ecto_projections,
      repo: MyApp.Projections.Repo
    ```

## Usage

Use Ecto schemas to define your read model:

```elixir
defmodule Projection do
  use Ecto.Schema

  schema "projections" do
    field :name, :string
  end
end
```

For each read model you will need to define a module that uses the `Commanded.Projections.Ecto` macro and configures the domain events to be projected.

The `project/2` macro expects the domain event and metadata. You can also use `project/1` if you do not need to use the event metadata. Inside the project block you have access to an [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html) data structure, available as the `multi` variable, for grouping multiple Repo operations. These will be executed within a single transaction. You can use Ecto.Multi to insert, update, and delete data.

```elixir
defmodule Projector do
  use Commanded.Projections.Ecto, name: "projection"

  project %AnEvent{name: name}, _metadata do
    Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
  end

  project %AnotherEvent{name: name} do
    Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
  end
end
```

### Supervision

Your projector module must be included in your application supervision tree:

```elixir
defmodule MyApp.Projections.Supervisor do
  use Supervisor

  alias MyApp.Projector

  def start_link do
    Supervisor.start_link(__MODULE__, nil)
  end

  def init(_) do
    children = [
      # projections
      worker(Commanded.Event.Handler, ["Projector", Projector], id: :projector),      
    ]

    supervise(children, strategy: :one_for_one)
  end
end
```
