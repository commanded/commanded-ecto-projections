# Commanded Ecto Projections

Read model projections for [Commanded](https://github.com/commanded/commanded) CQRS/ES applications using [Ecto](https://github.com/elixir-ecto/ecto) for persistence.

Read the [Changelog](CHANGELOG.md) for recent changes and the [Hex Docs](https://hexdocs.pm/commanded_ecto_projections/) on API usage.

> This README and the following guides follow the `master` branch which may not be the currently published version.

### Overview

- [Getting started](guides/Getting%20Started.md)
- [Usage](guides/Usage.md)
  - [Creating a read model](guides/Usage.md#creating-a-read-model)
  - [Creating a projector](guides/Usage.md#creating-a-projector)
  - [Supervision](guides/Usage.md#supervision)
  - [Error handling](guides/Usage.md#error-handling)
    - [`error/3` callback](guides/Usage.md#error3-callback)
    - [Error handling example](guides/Usage.md#error-handling-example)
  - [`after_update/3` callback](guides/Usage.md#after_update3-callback)
  - [Schema prefix](guides/Usage.md#schema-prefix)
  - [Rebuilding a projection](guides/Usage.md#rebuilding-a-projection)

### Example projector

```elixir
defmodule MyApp.ExampleProjector do
  use Commanded.Projections.Ecto,
    application: MyApp.Application,
    repo: MyApp.Projections.Repo,
    name: "MyApp.ExampleProjector"

  project %AnEvent{} = event, _metadata, fn multi ->
    %AnEvent{name: name} = event

    projection = %ExampleProjection{name: name}

    Ecto.Multi.insert(multi, :example_projection, projection)
  end
end
```

### Contributing

Pull requests to contribute new or improved features, and extend documentation are most welcome. Please follow the existing coding conventions.

You should include unit tests to cover any changes. Run `mix test` to execute the test suite:

```console
mix deps.get
MIX_ENV=test mix setup
mix test
```

### Contributors

- [Andrey Akulov](https://github.com/astery)
- [Ben Smith](https://github.com/slashdotdash)
- [CptBreeza](https://github.com/CptBreeza)
- [Florian Ebeling](https://github.com/febeling)
- [Sascha Wolf](https://github.com/Zeeker)
- [Tobiasz Małecki](https://github.com/amatalai)

## Need help?

Please [open an issue](https://github.com/commanded/commanded-ecto-projections/issues) if you encounter a problem, or need assistance. You can also seek help in the [Gitter chat room](https://gitter.im/commanded/Lobby) for Commanded.

For commercial support, and consultancy, please contact [Ben Smith](mailto:ben@10consulting.com).

## Copyright and License

Copyright (c) 2017 Ben Smith

This library is released under the MIT License. See the [LICENSE.md](./LICENSE.md) file for further details.
