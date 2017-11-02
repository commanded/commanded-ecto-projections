# Changelog

## v0.6.0

- Pass through any additional projector configuration options to Commanded event handler.
  Allows new Commanded features to be used without updating this library (e.g. specify `consistency` option).

## v0.5.0

- Allow an Ecto schema prefix to be defined in config or per handler ([#4](https://github.com/commanded/commanded-ecto-projections/pull/4)).

### Enhancements

## v0.4.0

### Enhancements

- Add `repo` option to `Commanded.Projections.Ecto` macro ([#1](https://github.com/commanded/commanded-ecto-projections/pull/1)).
- Optional `after_update/3` callback function in projectors.
