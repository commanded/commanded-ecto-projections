defmodule Commanded.Projections.EctoTest do
  use ExUnit.Case
  doctest Commanded.Projections.Ecto

  defmodule Event do
    defstruct [:name]
  end

  defmodule Projection do
    use Ecto.Schema

    schema "projections" do
      # ...
    end
  end

  defmodule Projector do
    use Commanded.Projections.Ecto, name: "projection"

    project %Event{} do
      Ecto.Multi.insert(multi, :my_projection, %Projection{})
    end
  end

  test "should handle a projected event" do
    assert :ok == Projector.handle(%Event{}, %{event_id: 1})
  end
end
