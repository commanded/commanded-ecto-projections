defmodule Commanded.Projections.RuntimeConfigProjector do
  use Commanded.Projections.Ecto

  alias Commanded.Projections.Events.AnEvent
  alias Commanded.Projections.Projection

  project %AnEvent{} = event, fn multi ->
    %AnEvent{name: name, pid: pid} = event

    send(pid, {:project, name})

    Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
  end
end
