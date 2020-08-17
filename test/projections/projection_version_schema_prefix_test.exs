defmodule Commanded.Projections.ProjectionVersionSchemaPrefixTest do
  use ExUnit.Case

  alias Commanded.Projections.Repo
  alias Commanded.Projections.Events.SchemaEvent

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
          name: "default_schema_prefix_projector"
      end

      assert_schema_prefix(DefaultSchemaPrefixProjector, nil)
    end

    test "should support static schema prefix" do
      defmodule StaticSchemaPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "static_schema_prefix_projector",
          schema_prefix: "static_schema_prefix"
      end

      assert_schema_prefix(StaticSchemaPrefixProjector, "static_schema_prefix")
    end

    test "should support static schema prefix in application config" do
      Application.put_env(:commanded_ecto_projections, :schema_prefix, "app_config_schema_prefix")

      defmodule AppConfigSchemaPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "app_config_schema_prefix_projector"
      end

      assert_schema_prefix(AppConfigSchemaPrefixProjector, "app_config_schema_prefix")
    end

    test "should support dynamic schema prefix" do
      defmodule DynamicSchemaPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "dynamic_schema_prefix_projector",
          schema_prefix: fn _event -> "dynamic_schema_prefix" end
      end

      assert_schema_prefix(DynamicSchemaPrefixProjector, "dynamic_schema_prefix")
    end

    test "should support optional `schema_prefix` callback function" do
      defmodule SchemaPrefixCallbackProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "schema_prefix_callback_projector"

        @impl Commanded.Projections.Ecto
        def schema_prefix(_event), do: "callback_schema_prefix"
      end

      assert_schema_prefix(SchemaPrefixCallbackProjector, "callback_schema_prefix")
    end

    test "should support `schema_prefix` callback function with different schema per event" do
      defmodule SchemaPrefixPerEventCallbackProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "schema_prefix_per_event_callback_projector"

        @impl Commanded.Projections.Ecto
        def schema_prefix(%_{schema: schema}), do: schema
      end

      assert schema_prefix(SchemaPrefixPerEventCallbackProjector, %SchemaEvent{schema: "schema1"}) ==
               "schema1"

      assert schema_prefix(SchemaPrefixPerEventCallbackProjector, %SchemaEvent{schema: "schema2"}) ==
               "schema2"

      assert schema_prefix(SchemaPrefixPerEventCallbackProjector, %SchemaEvent{schema: "schema3"}) ==
               "schema3"
    end

    test "should update the ProjectionVersion with a schema prefix" do
      defmodule TestPrefixProjector do
        use Commanded.Projections.Ecto,
          application: TestApplication,
          name: "TestPrefixProjector",
          schema_prefix: "test"

        project(%SchemaEvent{}, & &1)
      end

      alias TestPrefixProjector.ProjectionVersion

      :ok =
        TestPrefixProjector.handle(%SchemaEvent{}, %{
          handler_name: "TestPrefixProjector",
          event_number: 1
        })

      projection_version = Repo.get(ProjectionVersion, "TestPrefixProjector", prefix: "test")

      assert projection_version.last_seen_event_number == 1
    end

    test "should error when configured with an invalid schema prefix" do
      assert_raise ArgumentError,
                   "expected :schema_prefix option to be a string or a one-arity function, but got: :invalid",
                   fn ->
                     Code.eval_string("""
                     defmodule InvalidSchemaPrefixProjector do
                       use Commanded.Projections.Ecto,
                         application: TestApplication,
                         name: "invalid_schema_prefix_projector",
                         schema_prefix: :invalid
                     end
                     """)
                   end
    end
  end

  defp assert_schema_prefix(projector, expected_prefix) do
    prefix = schema_prefix(projector, %SchemaEvent{})

    assert prefix == expected_prefix
  end

  defp schema_prefix(projector, event) do
    apply(projector, :schema_prefix, [event])
  end
end
