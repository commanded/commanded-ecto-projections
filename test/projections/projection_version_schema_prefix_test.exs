defmodule Commanded.Projections.ProjectionVersionSchemaPrefixTest do
  use ExUnit.Case

  alias Commanded.Projections.Repo

  defmodule CustomSchemaPrefixProjector do
    use Commanded.Projections.Ecto,
      name: "my-custom-schema-prefix-projector",
      schema_prefix: "my-awesome-schema-prefix"
  end

  defmodule DefaultSchemaPrefixProjector do
    use Commanded.Projections.Ecto,
      name: "default-schema-prefix-projector"
  end

  setup do
    schema_prefix = Application.get_env(:commanded_ecto_projections, :schema_prefix)

    on_exit fn ->
      Application.put_env(:commanded_ecto_projections, :schema_prefix, schema_prefix)
    end

    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should support default `nil` schema prefix in ProjectionVersion" do
    prefix = DefaultSchemaPrefixProjector.ProjectionVersion.__schema__(:prefix)

    assert prefix == nil
  end

  test "should have custom schema prefix in ProjectionVersion" do
    prefix = CustomSchemaPrefixProjector.ProjectionVersion.__schema__(:prefix)

    assert prefix == "my-awesome-schema-prefix"
  end

  test "should allow custom schema prefix in application config" do
    Application.put_env(:commanded_ecto_projections, :schema_prefix, "app-config-schema-prefix")

    defmodule AppConfigSchemaPrefixProjector do
      use Commanded.Projections.Ecto,
        name: "app-config-schema-prefix-projector"
    end

    prefix = AppConfigSchemaPrefixProjector.ProjectionVersion.__schema__(:prefix)

    assert prefix == "app-config-schema-prefix"
  end

  test "should update the ProjectionVersion with a schema prefix" do
    defmodule TestPrefixProjector do
      use Commanded.Projections.Ecto,
        name: "test-projector",
        schema_prefix: "test"

      project _, do: multi
    end

    alias TestPrefixProjector.ProjectionVersion

    TestPrefixProjector.handle(:some_event, %{event_number: 1})

    assert Repo.get(ProjectionVersion, "test-projector").last_seen_event_number == 1
  end
end
