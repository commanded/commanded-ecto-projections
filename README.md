# Commanded Ecto Projections

[![Build Status](https://travis-ci.com/commanded/commanded-ecto-projections.svg?branch=master)](https://travis-ci.com/commanded/commanded-ecto-projections)
[![Module Version](https://img.shields.io/hexpm/v/commanded_ecto_projections.svg)](https://hex.pm/packages/commanded_ecto_projections)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/commanded_ecto_projections/)
[![Total Download](https://img.shields.io/hexpm/dt/commanded_ecto_projections.svg)](https://hex.pm/packages/commanded_ecto_projections)
[![License](https://img.shields.io/hexpm/l/commanded_ecto_projections.svg)](https://github.com/commanded/commanded-ecto-projections/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/commanded/commanded-ecto-projections.svg)](https://github.com/commanded/commanded-ecto-projections/commits/master)

> This README and the following guides follow the `master` branch which may not be the currently published version.

Model projections for [Commanded](https://github.com/commanded/commanded) CQRS/ES applications using [Ecto](https://github.com/elixir-ecto/ecto) for persistence.

Read the [Changelog](CHANGELOG.md) for recent changes and the [Hex Docs](https://hexdocs.pm/commanded_ecto_projections/) on API usage.

### Overview

- [Getting started](guides/getting_started.md)
- [Usage](guides/usage.md)
  - [Creating a read model](guides/usage.md#creating-a-read-model)
  - [Creating a projector](guides/usage.md#creating-a-projector)
  - [Supervision](guides/usage.md#supervision)
  - [Error handling](guides/usage.md#error-handling)
    - [`error/3` callback](guides/usage.md#error3-callback)
    - [Error handling example](guides/usage.md#error-handling-example)
  - [`after_update/3` callback](guides/usage.md#after_update3-callback)
  - [Schema prefix](guides/usage.md#schema-prefix)
  - [Rebuilding a projection](guides/usage.md#rebuilding-a-projection)

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

This library is released under the MIT License. See the [LICENSE.md](./LICENSE.md) file
for further details.
