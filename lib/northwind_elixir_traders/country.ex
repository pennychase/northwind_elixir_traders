defmodule NorthwindElixirTraders.Country do
  use Ecto.Schema
  import Ecto.{Changeset, Query}

  alias NorthwindElixirTraders.Repo

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

  def get_dial_by(field, value) when is_atom(field) and is_bitstring(value) do
    criterion = Keyword.new([{field, value}])
    Repo.one(from(c in __MODULE__, where: ^criterion, select: c.dial))
  end

  def get_dial(value) when is_bitstring(value) do
    dialcodes = [:name, :alpha3] |> Enum.map(&get_dial_by(&1, value)) |> Enum.filter(&(not is_nil(&1)))

    case dialcodes do
      [a, a] -> a     # found by both
      [a] -> a        # found by one
      [] -> nil       # found by neither
      [_a, _b] -> nil # ambiguous
    end
  end

end
