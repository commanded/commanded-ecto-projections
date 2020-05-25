defmodule Commanded.Projections.AfterUpdateCallbackTest do
  use ExUnit.Case
  doctest Commanded.Projections.Ecto

  alias Commanded.Projections.Repo

  defmodule AnEvent do
    defstruct [:pid, name: "AnEvent"]
  end

  defmodule Projection do
    use Ecto.Schema

    schema "projections" do
      field(:name, :string)
    end
  end

  defmodule Projector do
    use Commanded.Projections.Ecto,
      application: TestApplication,
      name: "projection"

    project %AnEvent{name: name}, fn multi ->
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    def after_update(event, metadata, changes) do
      send(event.pid, {:after_update, event, metadata, changes})
      :ok
    end
  end

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should call `after_update/3` function with event, metadata, and changes" do
    event = %AnEvent{pid: self()}
    metadata = %{event_number: 1}

    assert :ok == Projector.handle(event, metadata)

    assert_receive {:after_update, ^event, ^metadata, changes}

    case Map.get(changes, :my_projection) do
      %Projection{name: "AnEvent"} -> :ok
      _ -> flunk("invalid changes")
    end
  end
end
