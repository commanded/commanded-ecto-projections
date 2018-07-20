defmodule Commanded.Projections.ProjectionAssertions do
  import ExUnit.Assertions

  alias Commanded.Projections.Repo

  def assert_projections(schema, expected) do
    actual = Repo.all(schema) |> pluck(:name)

    assert actual == expected
  end

  def assert_seen_event(projection_name, expected_last_seen)
      when is_binary(projection_name) and is_integer(expected_last_seen) do
    assert {:ok, %{rows: [[^expected_last_seen]], num_rows: 1}} =
             Ecto.Adapters.SQL.query(
               Repo,
               "SELECT last_seen_event_number from projection_versions where projection_name = $1",
               [projection_name]
             )
  end

  defp pluck(enumerable, field) do
    Enum.map(enumerable, &Map.get(&1, field))
  end
end
