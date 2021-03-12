defmodule Commanded.Projections.AfterUpdateCallbackTest do
  use ExUnit.Case

  alias Commanded.Projections.Events.AnEvent
  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo

  defmodule Projector do
    use Commanded.Projections.Ecto,
      application: TestApplication,
      name: "Projector"

    project %AnEvent{name: name}, fn multi ->
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    def after_update(event, metadata, changes) do
      %{pid: pid} = event

      send(pid, {:after_update, event, metadata, changes})

      :ok
    end
  end

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "`after_update/3` callback function" do
    test "should be called after projecting with event, metadata, and changes" do
      event = %AnEvent{pid: self()}
      metadata = %{handler_name: "Projector", event_number: 1}

      assert :ok == Projector.handle(event, metadata)

      assert_receive {:after_update, ^event, ^metadata, changes}

      assert match?(%{my_projection: %Projection{name: "AnEvent"}}, changes)
    end

    test "should not be called when projecting an already seen event" do
      event = %AnEvent{pid: self()}
      metadata = %{handler_name: "Projector", event_number: 1}

      assert :ok == Projector.handle(event, metadata)

      assert_receive {:after_update, ^event, ^metadata, _changes}

      assert :ok == Projector.handle(event, metadata)

      refute_receive {:after_update, _event, _metadata, _changes}
    end
  end
end
