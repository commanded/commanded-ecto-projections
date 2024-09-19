defmodule Commanded.Projections.EctoProjectionBatchTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Commanded.Projections.Events.{AnEvent, AnotherEvent, ErrorEvent}
  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo

  defmodule BatchProjector do
    use Commanded.Projections.Ecto,
      application: TestApplication,
      name: "BatchProjector",
      callback_handler: :batch

    project_batch(events, fn multi ->
      projections =
        Enum.map(events, fn
          {%AnEvent{name: name}, _metadata} -> %{name: name}
          {%AnotherEvent{name: name}, _metadata} -> %{name: name}
          {%ErrorEvent{}, _metadata} -> :error
        end)

      if Enum.any?(projections, &(&1 == :error)) do
        Ecto.Multi.error(multi, :projection, :failure)
      else
        Ecto.Multi.insert_all(multi, :projection, Projection, projections)
      end
    end)
  end

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should handle multiple projected events" do
    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{}, %{handler_name: "BatchProjector", event_number: 1}},
               {%AnEvent{}, %{handler_name: "BatchProjector", event_number: 2}}
             ])

    assert_projections(Projection, ["AnEvent", "AnEvent"])
    assert_seen_event("BatchProjector", 2)
  end

  test "should handle two different types of projected events" do
    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{}, %{handler_name: "BatchProjector", event_number: 1}},
               {%AnotherEvent{}, %{handler_name: "BatchProjector", event_number: 2}}
             ])

    assert_projections(Projection, ["AnEvent", "AnotherEvent"])
    assert_seen_event("BatchProjector", 2)
  end

  test "should ignore already projected batch" do
    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{}, %{handler_name: "BatchProjector", event_number: 1}}
             ])

    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{}, %{handler_name: "BatchProjector", event_number: 1}}
             ])

    assert_projections(Projection, ["AnEvent"])
    assert_seen_event("BatchProjector", 1)
  end

  test "partial batch already seen should return an :ok" do
    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{name: "e1"}, %{handler_name: "BatchProjector", event_number: 1}},
               {%AnEvent{name: "e2"}, %{handler_name: "BatchProjector", event_number: 2}},
               {%AnEvent{name: "e3"}, %{handler_name: "BatchProjector", event_number: 3}}
             ])

    assert_projections(Projection, ["e1", "e2", "e3"])
    assert_seen_event("BatchProjector", 3)

    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{name: "e2"}, %{handler_name: "BatchProjector", event_number: 2}},
               {%AnEvent{name: "e3"}, %{handler_name: "BatchProjector", event_number: 3}},
               {%AnEvent{name: "e4"}, %{handler_name: "BatchProjector", event_number: 4}}
             ])
  end

  test "entire batches already seen should return an :ok" do
    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{name: "e1"}, %{handler_name: "BatchProjector", event_number: 1}},
               {%AnEvent{name: "e2"}, %{handler_name: "BatchProjector", event_number: 2}},
               {%AnEvent{name: "e3"}, %{handler_name: "BatchProjector", event_number: 3}}
             ])

    assert :ok ==
             BatchProjector.handle_batch([
               {%AnEvent{name: "e1"}, %{handler_name: "BatchProjector", event_number: 1}},
               {%AnEvent{name: "e2"}, %{handler_name: "BatchProjector", event_number: 2}},
               {%AnEvent{name: "e3"}, %{handler_name: "BatchProjector", event_number: 3}}
             ])
  end

  test "should return an error on failure" do
    assert {:error, :failure} ==
             BatchProjector.handle_batch([
               {%ErrorEvent{}, %{handler_name: "BatchProjector", event_number: 1}}
             ])

    assert_projections(Projection, [])
  end

  defmodule BatchProjectorAfterUpdateCallback do
    use Commanded.Projections.Ecto,
      application: TestApplication,
      callback_handler: :batch

    project_batch(events, fn multi ->
      projections =
        Enum.map(events, fn
          {%{name: name}, _metadata} -> %{name: name}
        end)

      Ecto.Multi.insert_all(multi, :projection, Projection, projections)
    end)

    def after_update_batch(events, changes) do
      {%{pid: pid}, _metadata} = List.first(events)

      send(pid, {:after_update_batch, length(events), changes})

      :ok
    end
  end

  test "should call after_update_batch/2 callback" do
    assert :ok ==
             BatchProjectorAfterUpdateCallback.handle_batch([
               {%AnEvent{pid: self()}, %{handler_name: "BatchProjector", event_number: 1}},
               {%AnEvent{pid: self()}, %{handler_name: "BatchProjector", event_number: 2}},
               {%AnEvent{pid: self()}, %{handler_name: "BatchProjector", event_number: 3}}
             ])

    assert_receive {:after_update_batch, 3, _changes}
  end

  test "should not compile if both project/2 and project_batch/1 are defined" do
    assert_raise CompileError, fn ->
      ast =
        quote do
          defmodule InvalidBatchProjector do
            use Commanded.Projections.Ecto, application: TestApplication

            project %AnEvent{}, _metadata, fn multi ->
              multi
            end

            project_batch(events, fn multi ->
              multi
            end)
          end
        end

      Code.eval_quoted(ast)
    end
  end
end
