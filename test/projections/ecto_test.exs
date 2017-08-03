defmodule Commanded.Projections.EctoTest do
  use ExUnit.Case
  doctest Commanded.Projections.Ecto

  alias Commanded.Projections.Repo

  defmodule AnEvent, do: defstruct [name: "AnEvent"]
  defmodule AnotherEvent, do: defstruct [name: "AnotherEvent"]
  defmodule IgnoredEvent, do: defstruct [name: "IgnoredEvent"]
  defmodule ErrorEvent, do: defstruct [name: "ErrorEvent"]

  defmodule Projection do
    use Ecto.Schema

    schema "projections" do
      field :name, :string
    end
  end

  defmodule Projector do
    use Commanded.Projections.Ecto, name: "projection"

    project %AnEvent{name: name}, _metadata do
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    project %AnotherEvent{name: name} do
      Ecto.Multi.insert(multi, :my_projection, %Projection{name: name})
    end

    project %ErrorEvent{} do
      Ecto.Multi.error(multi, :my_projection, :failure)
    end
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  test "should handle a projected event" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})

    assert_projections ["AnEvent"]
  end

  test "should handle two different types of projected events" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%AnotherEvent{}, %{event_number: 2})

    assert_projections ["AnEvent", "AnotherEvent"]
  end

  test "should ignore already projected event" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})

    assert_projections ["AnEvent"]
  end

  test "should ignore unprojected event" do
    assert :ok == Projector.handle(%IgnoredEvent{}, %{event_number: 1})

    assert_projections []
  end

  test "should ignore unprojected events amongst projections" do
    assert :ok == Projector.handle(%AnEvent{}, %{event_number: 1})
    assert :ok == Projector.handle(%IgnoredEvent{}, %{event_number: 2})
    assert :ok == Projector.handle(%AnotherEvent{}, %{event_number: 3})

    assert_projections ["AnEvent", "AnotherEvent"]
  end

  test "should return an error on failure" do
    assert {:error, :failure} == Projector.handle(%ErrorEvent{}, %{event_number: 1})

    assert_projections []
  end

  test "should ensure repo is configured" do
    repo = Application.get_env(:commanded_ecto_projections, :repo)

    try do
      Application.put_env(:commanded_ecto_projections, :repo, nil)

      assert_raise RuntimeError, "Commanded Ecto projections expects :repo to be configured in environment", fn ->
        Code.eval_string """
        defmodule UnconfiguredProjector do
          use Commanded.Projections.Ecto, name: "projector"
        end
        """
      end
    after
      Application.put_env(:commanded_ecto_projections, :repo, repo)
    end
  end

  test "should allow to set :repo as an option" do
    repo = Application.get_env(:commanded_ecto_projections, :repo)

    try do
      Application.put_env(:commanded_ecto_projections, :repo, nil)

      assert Code.eval_string """
      defmodule ProjectorConfiguredViaOpts do
        use Commanded.Projections.Ecto,
          name: "projector",
          repo: Commanded.Projections.Repo
      end
      """
    after
      Application.put_env(:commanded_ecto_projections, :repo, repo)
    end
  end

  test "should ensure projection name is present" do
    assert_raise RuntimeError, "UnnamedProjector expects :name to be given", fn ->
      Code.eval_string """
      defmodule UnnamedProjector do
        use Commanded.Projections.Ecto
      end
      """
    end
  end

  defp assert_projections(expected) do
    assert Repo.all(Projection) |> pluck(:name) == expected
  end

  defp pluck(enumerable, field) do
    Enum.map(enumerable, &Map.get(&1, field))
  end
end
