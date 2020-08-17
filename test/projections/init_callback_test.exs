defmodule Commanded.Projections.InitCallbackTest do
  use ExUnit.Case

  alias Commanded.Projections.Repo

  defmodule InitProjector do
    use Commanded.Projections.Ecto, application: TestApplication, name: "InitProjector"

    @impl Commanded.Event.Handler
    def init(config) do
      {reply_to, config} = Keyword.pop(config, :reply_to)

      if is_pid(reply_to), do: send(reply_to, {:init, config})

      {:ok, config}
    end
  end

  setup do
    start_supervised!(TestApplication)
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "`init/1` callback function" do
    test "should be called on start" do
      start_supervised!({InitProjector, reply_to: self()})

      assert_receive {:init, config}

      assert Keyword.get(config, :application) == TestApplication
      assert Keyword.get(config, :name) == "InitProjector"
    end
  end
end
