defmodule Commanded.Projections.ProjectionVersionSchemaPrefixTest do
  use ExUnit.Case

  alias Commanded.Projections.Repo

  defmodule AnEvent do
    defstruct [:pid, name: "AnEvent"]
  end

  setup do
    schema_prefix = Application.get_env(:commanded_ecto_projections, :schema_prefix)

    on_exit(fn ->
      Application.put_env(:commanded_ecto_projections, :schema_prefix, schema_prefix)
    end)

    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "schema prefix" do
    test "should default to `nil` schema prefix when not specified" do
      defmodule DefaultSchemaPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "default-schema-prefix-projector"
      end

      assert_schema_prefix(DefaultSchemaPrefixProjector, nil)
    end

    test "should support static schema prefix" do
      defmodule StaticSchemaPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "static-schema-prefix-projector",
          schema_prefix: "static-schema-prefix"
      end

      assert_schema_prefix(StaticSchemaPrefixProjector, "static-schema-prefix")
    end

    test "should support static schema prefix in application config" do
      Application.put_env(:commanded_ecto_projections, :schema_prefix, "app-config-schema-prefix")

      defmodule AppConfigSchemaPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "app-config-schema-prefix-projector"
      end

      assert_schema_prefix(AppConfigSchemaPrefixProjector, "app-config-schema-prefix")
    end

    test "should support dynamic schema prefix" do
      defmodule DynamicSchemaPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "dynamic-schema-prefix-projector",
          schema_prefix: fn _event -> "dynamic-schema-prefix" end
      end

      assert_schema_prefix(DynamicSchemaPrefixProjector, "dynamic-schema-prefix")
    end

    test "should support optional `schema_prefix` callback function" do
      defmodule SchemaPrefixCallbackProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "schema-prefix-callback-projector"

        @impl Commanded.Projections.Ecto
        def schema_prefix(_event), do: "callback-schema-prefix"
      end

      assert_schema_prefix(SchemaPrefixCallbackProjector, "callback-schema-prefix")
    end

    test "should update the ProjectionVersion with a schema prefix" do
      defmodule TestPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "test-projector",
          schema_prefix: "test"

        project(%AnEvent{}, & &1)
      end

      alias TestPrefixProjector.ProjectionVersion

      TestPrefixProjector.handle(%AnEvent{}, %{event_number: 1})

      assert Repo.get(ProjectionVersion, "test-projector", prefix: "test").last_seen_event_number ==
               1
    end
  end

  defp assert_schema_prefix(projector, expected_prefix) do
    prefix = apply(projector, :schema_prefix, [%AnEvent{}])

    assert prefix == expected_prefix
  end
end
