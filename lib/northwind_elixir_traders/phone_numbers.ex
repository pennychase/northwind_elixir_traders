defmodule NorthwindElixirTraders.PhoneNumbers do
  import Ecto.Changeset

  alias NorthwindElixirTraders.{Repo, Country}

  @intl_regex ~r/^\+((?:9[679]|8[035789]|6[789]|5[90]|42|3[578]|2[1-689])|9[0-58]|8[1246]|6[0-6]|5[1-8]|4[\
013-9]|3[0-469]|2[70]|7|1)(?:\W*\d){0,13}\d$/

  @nanp_regex ~r/^\(?([0-9]{3})\)?[-. ]?([0-9]{3})[-. ]?([0-9]{4})$/

  # Helper functions for phone number validation

  def is_intl?(phone) when is_bitstring(phone), do: Regex.match?(@intl_regex, phone)

  def is_nanp?(phone) when is_bitstring(phone), do: Regex.match?(@nanp_regex, phone)

  def make_readable(phone) when is_bitstring(phone) do
    phone
    |> then(&Regex.replace(~r/[^\d^\s]/, &1, " "))
    |> then(&Regex.replace(~r/\s+/, &1, " "))
    |> String.trim_leading()
  end

  def compose_intl(dialcode, readable) when is_bitstring(dialcode) and is_bitstring(readable) do
    to_string(["+", dialcode, " ", readable])
  end

  def handle_phone(phone, nil = _country) when is_bitstring(phone) do
    dc = Country.get_dial("USA")
    readable = make_readable(phone)
    if is_nanp?(phone), do: compose_intl(dc, readable), else: nil
  end

  def handle_phone(phone, country) when is_bitstring(phone) and is_bitstring(country) do
    dc = Country.get_dial(country)
    readable = make_readable(phone)
    if is_nil(dc), do: nil, else: compose_intl(dc, readable)
  end

  def intlize(phone, country) when is_bitstring(phone) and (is_bitstring(country) or is_nil(country)) do
    if is_intl?(phone), do: phone, else: handle_phone(phone, country)
  end

  # Changeset validation function

  def validate_phone(changeset, phone_field \\ :phone, country_field \\ nil)
      when is_map(changeset) and is_atom(phone_field) and is_atom(country_field) do
    cs_error_keys = changeset |> Map.get(:errors) |> Keyword.keys()
    errors = Enum.map([phone_field, country_field], &Enum.member?(cs_error_keys, &1))

    if true in errors, do: changeset, else: process_changeset(changeset, phone_field, country_field)
  end

  def process_changeset(changeset, phone_field, nil = _country_field)
      when is_map(changeset) and is_atom(phone_field) do
    phone = get_field(changeset, phone_field)
    phone_new = intlize(phone, nil)

    if is_nil(phone_new) do
      add_error(changeset, phone_field,
        "ambiguous: %{phone} is not a NANP-formatted phone number", phone: phone)
    else
      put_change(changeset, phone_field, phone_new)
    end
  end

  def process_changeset(changeset, phone_field, country_field)
      when is_map(changeset) and is_atom(phone_field) and not is_nil(country_field) do
    country = get_field(changeset, country_field)
    phone = get_field(changeset, phone_field)
    phone_new = intlize(phone, country)

    if is_nil(phone_new) do
        add_error(changeset,  phone_field,
          "could not internationalize phone number '%{phone}' for country '%{country}",
          phone: phone, country: country)
    else
      put_change(changeset, phone_field, phone_new)
    end
  end

  # Import country codes

  # Country codes are at https://raw.githubusercontent.com/datasets/country-codes/master/data/country-codes.csv
  # We're using a specific commit for stability
  @url "https://raw.githubusercontent.com/datasets/country-codes/2ed03b6993e817845c504ce9626d519376c8acaa/data/country-codes.csv"

  # Retrieve Country Codes and import into Country schema

  def get_csv_rows() do
    {status, result} = :httpc.request(@url)

    case {status, result} do
      {:ok, {_status, _headers, body}} ->
        {:ok, body |> List.to_string() |> String.trim() |> String.split("\n")
                   |> Enum.map(&fix_csv_row/1) |> Enum.map(&String.split(&1, ","))
        }
      {:error, {status, _, _}} -> {:error, status}
    end
  end

  def fix_csv_row(row) when is_bitstring(row) do
    regex = ~r/"([^"]*)"/

    String.replace(row, regex, &(String.replace(&1, ",", "|") |> String.replace("\"", "")))
  end

  def process_csv({:ok, [headings | data]}) do
    indices = ["CLDR display name", "Dial", "ISO3166-1-Alpha-3"]
      |> Enum.map(fn colname -> Enum.find_index(headings, &(&1 == colname)) end)

    data
    |> Enum.map(fn row -> Enum.map(indices, &Enum.at(row, &1)) end)
    |> Enum.filter(fn r -> "" not in r and nil not in r end)
    |> Enum.map(&List.to_tuple(&1))
    |> Enum.map(fn {country, dial, iso} -> {country, String.replace(dial, "-", ""), iso} end)
  end

  def csv_tuple_to_record({_name, _dial, _alpha3} = country) do
    [:name, :dial, :alpha3]
    |> Enum.zip(Tuple.to_list(country))
    |> Map.new()
    |> then(&Country.changeset(%Country{}, &1))
    |> Repo.insert()
  end

  def import() do
    get_csv_rows()
    |> process_csv()
    |> Enum.map(&csv_tuple_to_record/1)
  end

end
