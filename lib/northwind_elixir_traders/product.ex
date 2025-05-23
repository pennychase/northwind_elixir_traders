defmodule NorthwindElixirTraders.Product do
  use Ecto.Schema
  import Ecto.Changeset
  alias NorthwindElixirTraders.{Category, Validations, Supplier}

  @name_mxln 50

  schema "products" do
    field(:name, :string)
    field(:unit, :string)
    field(:price, :float)
    field(:category_id, :integer)
    belongs_to(:supplier, Supplier)
    belongs_to(:category, Category, define_field: false)

    timestamps(type: :utc_datetime)
  end

  def changeset(data, params \\ %{}) do
    permitted =[:name, :unit, :price, :category_id]
    required = permitted

    data
    |> cast(params, permitted)
    |> validate_required(required)
    |> validate_length(:name, max: @name_mxln)
    |> Validations.validate_foreign_key_id(Category, :category_id)
    |> unique_constraint([:name])
  end

end
