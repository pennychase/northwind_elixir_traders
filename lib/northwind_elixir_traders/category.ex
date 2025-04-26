defmodule NorthwindElixirTraders.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @name_maxlen 50
  @desc_maxlen 100

  schema "categories" do
    field(:name, :string)
    field(:description, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(data, params \\ %{}) do
    permitted = [:name, :description]
    required = [:name]

    data
    |> cast(params, permitted)
    |> validate_required(required)
    |> validate_length(:name, max: @name_maxlen)
    |> validate_length(:description, max: @desc_maxlen)


  end
  
end