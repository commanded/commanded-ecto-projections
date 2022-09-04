defmodule Commanded.Projections.RuntimeConfigProjectorTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Commanded.EventStore.RecordedEvent
  alias Commanded.Projections.Events.AnEvent
  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo
  alias Commanded.Projections.RuntimeConfigProjector
  alias Commanded.UUID

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "runtime config projector" do
    setup do
      projector1 =
        start_supervised!(
          {RuntimeConfigProjector, application: TestApplication, name: "RuntimeProjector1"}
        )

      projector2 =
        start_supervised!(
          {RuntimeConfigProjector, application: TestApplication, name: "RuntimeProjector2"}
        )

      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), projector1)
      Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), projector2)

      [projector1: projector1, projector2: projector2]
    end

    test "should handle a projected event", %{projector1: projector1} do
      send_events(projector1, [
        %RecordedEvent{
          event_number: 1,
          event_id: UUID.uuid4(),
          data: %AnEvent{pid: self()},
          metadata: %{}
        }
      ])

      assert_receive {:project, "AnEvent"}

      assert_projections(Projection, ["AnEvent"])
      assert last_seen_event("RuntimeProjector1") == 1
      assert last_seen_event("RuntimeProjector2") == nil
    end
  end

  defp send_events(projector, events) do
    send(projector, {:events, events})
  end
end
