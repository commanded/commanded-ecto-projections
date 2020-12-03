defmodule ErrorProjector do
  use Commanded.Projections.Ecto, application: TestApplication, name: "ErrorProjector"

  alias Commanded.Event.FailureContext

  alias Commanded.Projections.Events.{
    AnEvent,
    ErrorEvent,
    RaiseEvent,
    ExceptionEvent,
    InvalidMultiEvent
  }

  alias Commanded.Projections.Projection

  project(%AnEvent{name: name, pid: pid} = event, fn multi ->
    send(pid, event)

    Ecto.Multi.insert(multi, :projection, %Projection{name: name})
  end)

  project(%ErrorEvent{name: name}, fn multi ->
    Ecto.Multi.insert(multi, :projection, %Projection{name: name})

    {:error, :failed}
  end)

  project(%ExceptionEvent{}, fn multi ->
    # Attempt an invalid insert due to `name` type mismatch (expects a string).
    Ecto.Multi.insert(multi, :projection, %Projection{name: 1})
  end)

  project(%RaiseEvent{message: message}, fn _multi ->
    raise RuntimeError, message: message
  end)

  project(%InvalidMultiEvent{name: name}, fn multi ->
    # Attempt to execute an invalid Ecto query (comparison with `nil` is forbidden as it is unsafe).
    query = from(p in Projection, where: p.name == ^name)

    Ecto.Multi.update_all(multi, :projection, query, set: [name: name])
  end)

  @impl Commanded.Event.Handler
  def error({:error, :failed} = error, %ErrorEvent{} = event, %FailureContext{}) do
    %ErrorEvent{pid: pid} = event

    send(pid, error)

    :skip
  end

  @impl Commanded.Event.Handler
  def error({:error, _error} = error, %ExceptionEvent{} = event, %FailureContext{}) do
    %ExceptionEvent{pid: pid} = event

    send(pid, error)

    :skip
  end

  @impl Commanded.Event.Handler
  def error({:error, _error} = error, %RaiseEvent{} = event, %FailureContext{}) do
    %RaiseEvent{pid: pid} = event

    send(pid, error)

    :skip
  end

  @impl Commanded.Event.Handler
  def error({:error, _error} = error, %InvalidMultiEvent{} = event, %FailureContext{}) do
    %InvalidMultiEvent{pid: pid} = event

    send(pid, error)

    :skip
  end
end
