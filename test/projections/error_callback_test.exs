defmodule Commanded.Projections.ErrorCallbackTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Commanded.Event.FailureContext
  alias Commanded.EventStore.RecordedEvent
  alias Commanded.Projections.Events.{AnEvent, ErrorEvent, ExceptionEvent, InvalidMultiEvent}
  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo

  defmodule ErrorProjector do
    use Commanded.Projections.Ecto, application: TestApplication, name: "ErrorProjector"

    project %AnEvent{name: name, pid: pid} = event, fn multi ->
      send(pid, event)

      Ecto.Multi.insert(multi, :projection, %Projection{name: name})
    end

    project %ErrorEvent{name: name}, fn multi ->
      Ecto.Multi.insert(multi, :projection, %Projection{name: name})

      {:error, :failed}
    end

    project %ExceptionEvent{}, fn multi ->
      # Attempt an invalid insert due to `name` type mismatch (expects a string).
      Ecto.Multi.insert(multi, :projection, %Projection{name: 1})
    end

    project %InvalidMultiEvent{name: name}, fn multi ->
      # Attempt to execute an invalid Ecto query (comparison with `nil` is forbidden as it is unsafe).
      query = from(p in Projection, where: p.name == ^name)

      Ecto.Multi.update_all(multi, :projection, query, set: [name: name])
    end

    @impl Commanded.Event.Handler
    def error({:error, :failed} = error, %ErrorEvent{pid: pid}, %FailureContext{}) do
      send(pid, error)

      :skip
    end

    @impl Commanded.Event.Handler
    def error({:error, _error} = error, %ExceptionEvent{pid: pid}, %FailureContext{}) do
      send(pid, error)

      :skip
    end

    @impl Commanded.Event.Handler
    def error({:error, _error} = error, %InvalidMultiEvent{pid: pid}, %FailureContext{}) do
      send(pid, error)

      :skip
    end
  end

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should allow returning an error tagged tuple from `project` macro" do
    event = %ErrorEvent{pid: self()}
    metadata = %{handler_name: "ErrorProjector", event_number: 1}

    assert {:error, :failed} == ErrorProjector.handle(event, metadata)
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

  defp start_projector(_context) do
    projector = start_supervised!(ErrorProjector)

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), projector)

    [projector: projector]
  end
end
