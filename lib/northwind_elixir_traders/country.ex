defmodule NorthwindElixirTraders.Country do
  use Ecto.Schema
  import Ecto.Changeset

  # alias NorthwindElixirTraders.{Supplier, Customer}

  @name_mxlen 50
  @dial_mxlen 14

  schema "countries" do
    field(:name, :string)
    field(:dial, :string)
    field(:alpha3, :string)
    # has_many(:suppliers, Supplier, on_replace: :nilify)
    # has_many(:customers, Customer, on_replace: :nilify)

    timestamps(type: :utc_datetime)
  end

  def changeset(data, params \\ %{}) do
    permitted = [:name, :dial, :alpha3]
    required = permitted

    data
    |> cast(params, permitted)
    |> validate_required(required)
    |> validate_length(:name, max: @name_mxlen)
    |> validate_length(:dial, max: @dial_mxlen)
    |> validate_length(:alpha3, is: 3)
    |> unique_constraint([:name])
  end

end
