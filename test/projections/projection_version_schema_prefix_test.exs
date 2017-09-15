defmodule Commanded.Projections.ProjectionVersionSchemaPrefixTest do
  use ExUnit.Case

  defmodule CustomSchemaPrefixProjector do
    use Commanded.Projections.Ecto,
      name: "my-custom-schema-prefix-projector",
      schema_prefix: "my-awesome-schema-prefix"
  end

  test "should have custom schema prefix in ProjectionVersion" do
    prefix = CustomSchemaPrefixProjector.ProjectionVersion.__schema__(:prefix)

    assert prefix == "my-awesome-schema-prefix"
  end
end
