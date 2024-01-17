defmodule Commanded.Projections.ErrorCallbackTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions
  import ExUnit.CaptureLog
  import Mox

  alias Commanded.EventStore.Adapters.Mock, as: MockEventStore
  alias Commanded.EventStore.RecordedEvent

  alias Commanded.Projections.Events.{
    AnEvent,
    ErrorEvent,
    ExceptionEvent,
    InvalidMultiEvent,
    RaiseEvent
  }

  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo
  alias Commanded.UUID

  setup [:set_mox_global, :stub_event_store, :verify_on_exit!]

  setup do
    start_supervised!({TestApplication, event_store: [adapter: MockEventStore]})
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "error handling" do
    setup [:start_projector]

    test "should allow returning an error tagged tuple from `project` macro", %{
      projector: projector
    } do
      event = %ErrorEvent{pid: self()}
      metadata = %{handler_name: "ErrorProjector", event_number: 1}

      events = [
        %RecordedEvent{event_number: 1, event_id: UUID.uuid4(), data: event, metadata: metadata}
      ]

      send(projector, {:events, events})

      assert_receive {:error, :failed}
    end

    test "should rescue exceptions in `project` macro", %{projector: projector} do
      event = %RaiseEvent{pid: self(), message: "it crashed, it crashed, it crashed"}
      metadata = %{event_number: 1}

      events = [
        %RecordedEvent{event_number: 1, event_id: UUID.uuid4(), data: event, metadata: metadata}
      ]

      log =
        capture_log(fn ->
          send(projector, {:events, events})

          assert_receive {:error, %RuntimeError{message: "it crashed, it crashed, it crashed"}}
        end)

      assert log =~ "** (RuntimeError) it crashed, it crashed, it crashed"

      assert log =~
               "test/support/error_projector.ex:34: anonymous fn/2 in ErrorProjector.handle/2"
    end
  end

  describe "`error/3` callback function" do
    setup [:start_projector]

    test "should be called on error", %{projector: projector} do
      event = %ErrorEvent{pid: self()}
      metadata = %{event_number: 1}

      events = [
        %RecordedEvent{event_number: 1, event_id: UUID.uuid4(), data: event, metadata: metadata}
      ]

      send(projector, {:events, events})

      assert_receive {:error, :failed}
      assert Process.alive?(projector)
    end

    test "should be called on exception", %{projector: projector} do
      event = %ExceptionEvent{pid: self()}
      metadata = %{event_number: 1}

      events = [
        %RecordedEvent{event_number: 1, event_id: UUID.uuid4(), data: event, metadata: metadata}
      ]

      send(projector, {:events, events})

      assert_receive {:error, %Ecto.ChangeError{}}
      assert Process.alive?(projector)
    end

    test "should be called on invalid `Ecto.Multi`", %{projector: projector} do
      event = %InvalidMultiEvent{pid: self()}
      metadata = %{event_number: 1}

      events = [
        %RecordedEvent{event_number: 1, event_id: UUID.uuid4(), data: event, metadata: metadata}
      ]

      send(projector, {:events, events})

      assert_receive {:error, %ArgumentError{}}
      assert Process.alive?(projector)
    end

    test "should continue on error after skipping problematic events", %{projector: projector} do
      events = [
        %RecordedEvent{
          event_number: 1,
          event_id: UUID.uuid4(),
          data: %ErrorEvent{pid: self()},
          metadata: %{event_number: 1}
        },
        %RecordedEvent{
          event_number: 2,
          event_id: UUID.uuid4(),
          data: %ExceptionEvent{pid: self()},
          metadata: %{event_number: 2}
        },
        %RecordedEvent{
          event_number: 3,
          event_id: UUID.uuid4(),
          data: %AnEvent{pid: self()},
          metadata: %{event_number: 3}
        }
      ]

      send(projector, {:events, events})

      assert_receive {:error, :failed}
      assert_receive {:error, %Ecto.ChangeError{}}
      assert_receive %AnEvent{}

      assert Process.alive?(projector)
      assert_projections(Projection, ["AnEvent"])
      assert_seen_event("ErrorProjector", 3)
    end
  end

  defp stub_event_store(_context) do
    stub(MockEventStore, :ack_event, fn _adapter_meta, _pid, _event -> :ok end)

    stub(MockEventStore, :child_spec, fn _application, _config ->
      {:ok, [], %{}}
    end)

    stub(MockEventStore, :subscribe_to, fn
      _event_store, :all, _handler_name, _handler, _subscribe_from, _opts ->
        {:ok, self()}
    end)

    :ok
  end

  defp start_projector(_context) do
    projector = start_supervised!(ErrorProjector)

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), projector)

    [projector: projector]
  end
end
