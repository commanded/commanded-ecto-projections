# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.2.1 - 2020-12-03

- Allow exceptions to be rescued by Commanded's event handler ([#37](https://github.com/commanded/commanded-ecto-projections/pull/37)).

## v1.2.0 - 2020-08-18

- Support runtime projector names ([#32](https://github.com/commanded/commanded-ecto-projections/pull/32)).
- Support `schema_prefix/2` function ([#33](https://github.com/commanded/commanded-ecto-projections/pull/33)).

---

## v1.1.0 - 2020-05-25

### Enhancements

- Dynamic schema prefix ([#28](https://github.com/commanded/commanded-ecto-projections/pull/28)).
- Support Commanded v1.1.0.

---

## v1.0.0 - 2019-11-21

### Enhancements

- Support multiple Commanded apps ([#25](https://github.com/commanded/commanded-ecto-projections/pull/25)).
- Add `.formatter.exs` to Hex package ([#19](https://github.com/commanded/commanded-ecto-projections/pull/19)).
- Add microseconds to timestamp fields in `projection_versions` ([#22](https://github.com/commanded/commanded-ecto-projections/pull/22)).

---

## v0.8.0 - 2019-01-23

### Enhancements

- Upgrade to Ecto v3 ([#17](https://github.com/commanded/commanded-ecto-projections/pull/17)).
- Use lambda instead of unhygienic var in projection macros ([#13](https://github.com/commanded/commanded-ecto-projections/pull/13)).

  Previously _magic_ `multi`:

  ```elixir
  project %AnEvent{name: name}, _metadata do
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end
  ```

  Now `multi` is provided as a argument to the project function:

  ```elixir
  project %AnEvent{name: name}, _metadata, fn multi ->
    Ecto.Multi.insert(multi, :example_projection, %ExampleProjection{name: name})
  end
  ```

  The previous `do` block approach is still supported, but has been deprecated. It will be removed in the next release.

---

## v0.7.1 - 2018-07-24

### Bug fixes

- Ensure errors encountered while building the `Ecto.Multi` data structure within a `project` function are caught and passed to the `error/3` callback.

## v0.7.0 - 2018-07-22

### Enhancements

- Support Commanded's event handler `error/3` callback ([#12](https://github.com/commanded/commanded-ecto-projections/pull/12)).

---

## v0.6.0 - 2017-09-29

### Enhancements

- Pass through any additional projector configuration options to Commanded event handler.
  Allows new Commanded features to be used without updating this library (e.g. specify `consistency` option).

---

## v0.5.0 - 2017-09-15

### Enhancements

- Allow an Ecto schema prefix to be defined in config or per handler ([#4](https://github.com/commanded/commanded-ecto-projections/pull/4)).

---

## v0.4.0 - 2017-08-03

### Enhancements

- Add `repo` option to `Commanded.Projections.Ecto` macro ([#1](https://github.com/commanded/commanded-ecto-projections/pull/1)).
- Optional `after_update/3` callback function in projectors.
