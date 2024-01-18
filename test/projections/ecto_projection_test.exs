defmodule Commanded.Projections.EctoProjectionTest do
  use ExUnit.Case

  import Commanded.Projections.ProjectionAssertions

  alias Commanded.Projections.Events.{AnEvent, AnotherEvent, ErrorEvent, IgnoredEvent}
  alias Commanded.Projections.Projection
  alias Commanded.Projections.Repo

  defmodule Projector do
    use Commanded.Projections.Ecto, application: TestApplication, name: "Projector"

    project %AnEvent{name: name}, _metadata, fn multi ->
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    project %AnotherEvent{name: name}, fn multi ->
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    project %ErrorEvent{}, fn multi ->
      Ecto.Multi.error(multi, :my_projection, :failure)
    end
  end

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should handle a projected event" do
    assert :ok == Projector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})

    assert_projections(Projection, ["AnEvent"])
    assert_seen_event("Projector", 1)
  end

  test "should handle two different types of projected events" do
    assert :ok == Projector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})
    assert :ok == Projector.handle(%AnotherEvent{}, %{handler_name: "Projector", event_number: 2})

    assert_projections(Projection, ["AnEvent", "AnotherEvent"])
    assert_seen_event("Projector", 2)
  end

  test "should ignore already projected event" do
    assert :ok == Projector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})
    assert :ok == Projector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})
    assert :ok == Projector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})

    assert_projections(Projection, ["AnEvent"])
    assert_seen_event("Projector", 1)
  end

  test "should ignore unprojected event" do
    assert :ok == Projector.handle(%IgnoredEvent{}, %{event_number: 1})

    assert_projections(Projection, [])
  end

  test "should ignore unprojected events amongst projections" do
    assert :ok == Projector.handle(%AnEvent{}, %{handler_name: "Projector", event_number: 1})
    assert :ok == Projector.handle(%IgnoredEvent{}, %{handler_name: "Projector", event_number: 2})
    assert :ok == Projector.handle(%AnotherEvent{}, %{handler_name: "Projector", event_number: 3})
    assert :ok == Projector.handle(%IgnoredEvent{}, %{handler_name: "Projector", event_number: 4})

    assert_projections(Projection, ["AnEvent", "AnotherEvent"])
    assert_seen_event("Projector", 3)
  end

  test "should prevent first event being projected more than once" do
    tasks =
      Enum.map(1..5, fn _index ->
        Task.async(Projector, :handle, [
          %AnEvent{name: "Event1"},
          %{handler_name: "Projector", event_number: 1}
        ])
      end)

    results = Task.await_many(tasks)

    assert Enum.uniq(results) == [:ok]

    assert_projections(Projection, ["Event1"])
    assert_seen_event("Projector", 1)
  end

  test "should prevent an event being projected more than once" do
    Projector.handle(%AnEvent{name: "Event1"}, %{handler_name: "Projector", event_number: 1})
    Projector.handle(%AnEvent{name: "Event2"}, %{handler_name: "Projector", event_number: 2})

    tasks =
      Enum.map(1..5, fn _index ->
        Task.async(Projector, :handle, [
          %AnEvent{name: "Event3"},
          %{handler_name: "Projector", event_number: 3}
        ])
      end)

    results = Task.await_many(tasks)

    assert Enum.uniq(results) == [:ok]

    assert_projections(Projection, ["Event1", "Event2", "Event3"])
    assert_seen_event("Projector", 3)
  end

  test "should prevent an event being projected more than once after an ignored event" do
    Projector.handle(%AnEvent{name: "Event1"}, %{handler_name: "Projector", event_number: 1})
    Projector.handle(%AnEvent{name: "Event2"}, %{handler_name: "Projector", event_number: 2})
    Projector.handle(%IgnoredEvent{name: "Event2"}, %{handler_name: "Projector", event_number: 3})

    tasks =
      Enum.map(1..5, fn _index ->
        Task.async(Projector, :handle, [
          %AnEvent{name: "Event4"},
          %{handler_name: "Projector", event_number: 4}
        ])
      end)

    results = Task.await_many(tasks)

    assert Enum.uniq(results) == [:ok]

    assert_projections(Projection, ["Event1", "Event2", "Event4"])
    assert_seen_event("Projector", 4)
  end

  test "should return an error on failure" do
    assert {:error, :failure} ==
             Projector.handle(%ErrorEvent{}, %{handler_name: "Projector", event_number: 1})

    assert_projections(Projection, [])
  end

  test "should ensure repo is configured" do
    repo = Application.get_env(:commanded_ecto_projections, :repo)

    try do
      Application.put_env(:commanded_ecto_projections, :repo, nil)

      assert_raise RuntimeError,
                   "Commanded Ecto projections expects :repo to be configured in environment",
                   fn ->
                     Code.eval_string("""
                     defmodule UnconfiguredProjector do
                       use Commanded.Projections.Ecto, application: TestApplication, name: "projector"
                     end
                     """)
                   end
    after
      Application.put_env(:commanded_ecto_projections, :repo, repo)
    end
  end

  test "should allow to set `:repo` as an option" do
    repo = Application.get_env(:commanded_ecto_projections, :repo)

    try do
      Application.put_env(:commanded_ecto_projections, :repo, nil)

      assert Code.eval_string("""
             defmodule ProjectorConfiguredViaOpts do
               use Commanded.Projections.Ecto,
                 application: TestApplication,
                 name: "projector",
                 repo: Commanded.Projections.Repo
             end
             """)
    after
      Application.put_env(:commanded_ecto_projections, :repo, repo)
    end
  end

  defmodule UnnamedProjector do
    use Commanded.Projections.Ecto, application: TestApplication
  end

  test "should ensure projection name is present on start" do
    expected_error =
      "Commanded.Projections.EctoProjectionTest.UnnamedProjector expects :name option"

    assert_raise ArgumentError, expected_error, fn ->
      UnnamedProjector.start_link()
    end
  end
end
