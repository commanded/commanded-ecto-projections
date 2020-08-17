defmodule Commanded.Projections.DeprecatedProjectionTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions
  import ExUnit.CaptureIO

  alias Commanded.Projections.Repo
  alias Commanded.Projections.Events.AnEvent
  alias Commanded.Projections.Projection

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should handle a projected event" do
    capture_io(:stderr, fn ->
      defmodule DeprecatedProjector do
        use Commanded.Projections.Ecto, application: TestApplication, name: "DeprecatedProjector"

        project %AnEvent{name: name}, _metadata do
          Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
        end
      end

      assert :ok ==
               DeprecatedProjector.handle(%AnEvent{}, %{
                 handler_name: "DeprecatedProjector",
                 event_number: 1
               })

      assert_projections(Projection, ["AnEvent"])
      assert_seen_event("DeprecatedProjector", 1)
    end)
  end

  test "should warn project/2 macro deprecated" do
    assert capture_io(:stderr, fn ->
             defmodule DeprecatedProjectorWarn2 do
               use Commanded.Projections.Ecto,
                 application: TestApplication,
                 name: "DeprecatedProjectorWarn2"

               project %AnEvent{name: name} do
                 Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
               end
             end
           end) =~
             "project macro with \"do end\" block is deprecated; use project/2 with function instead"
  end

  test "should warn project/3 macro deprecated" do
    assert capture_io(:stderr, fn ->
             defmodule DeprecatedProjectorWarn3 do
               use Commanded.Projections.Ecto,
                 application: TestApplication,
                 name: "DeprecatedProjectorWarn3"

               project %AnEvent{name: name}, _metadata do
                 Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
               end
             end
           end) =~
             "project macro with \"do end\" block is deprecated; use project/3 with function instead"
  end
end
