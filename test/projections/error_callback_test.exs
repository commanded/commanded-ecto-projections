defmodule Commanded.Projections.ErrorCallbackTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Commanded.Event.FailureContext
  alias Commanded.EventStore.RecordedEvent
  alias Commanded.Projections.Repo

  defmodule AnEvent do
    defstruct [:pid, name: "AnEvent"]
  end

  defmodule ErrorEvent do
    defstruct [:pid, name: "ErrorEvent"]
  end

  defmodule ExceptionEvent do
    defstruct [:pid, name: "ExceptionEvent"]
  end

  defmodule InvalidMultiEvent do
    defstruct [:pid, :name]
  end

  defmodule Projection do
    use Ecto.Schema

    schema "projections" do
      field(:name, :string)
    end
  end

  defmodule ErrorProjector do
    use Commanded.Projections.Ecto, name: "ErrorProjector"

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

    def error({:error, :failed} = error, %ErrorEvent{pid: pid}, %FailureContext{}) do
      send(pid, error)

      :skip
    end

    def error({:error, _error} = error, %ExceptionEvent{pid: pid}, %FailureContext{}) do
      send(pid, error)

      :skip
    end

    def error({:error, _error} = error, %InvalidMultiEvent{pid: pid}, %FailureContext{}) do
      send(pid, error)

      :skip
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should allow returning an error tagged tuple from `project` macro" do
    event = %ErrorEvent{pid: self()}
    metadata = %{event_number: 1}

    assert {:error, :failed} == ErrorProjector.handle(event, metadata)
  end

  describe "`error` callback function" do
    setup [
      :start_commanded,
      :start_projector
    ]

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

  defp start_commanded(_context) do
    {:ok, _pid} = Commanded.EventStore.Adapters.InMemory.start_link()
    {:ok, _app} = Application.ensure_all_started(:commanded)

    on_exit(fn ->
      :ok = Application.stop(:commanded)
    end)

    :ok
  end

  defp start_projector(_context) do
    {:ok, projector} = ErrorProjector.start_link()

    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), projector)

    [projector: projector]
  end
end
