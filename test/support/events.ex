defmodule Commanded.Projections.Events do
  defmodule AnEvent do
    defstruct [:pid, name: "AnEvent"]
  end

  defmodule AnotherEvent do
    defstruct [:pid, name: "AnotherEvent"]
  end

  defmodule IgnoredEvent do
    defstruct [:pid, name: "IgnoredEvent"]
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

  defmodule SchemaEvent do
    defstruct [:schema, name: "SchemaEvent"]
  end
end
