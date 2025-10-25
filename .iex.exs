import Ecto.Query

alias NorthwindElixirTraders.Category
alias NorthwindElixirTraders.Repo
alias NorthwindElixirTraders.Employee
alias NorthwindElixirTraders.Supplier
alias NorthwindElixirTraders.Product
alias NorthwindElixirTraders.DataImporter
alias NorthwindElixirTraders.Shipper
alias NorthwindElixirTraders.PhoneNumbers

IEx.configure(inspect: [charlists: :as_lists])

url = "https://raw.githubusercontent.com/datasets/country-codes/2ed03b6993e817845c504ce9626d519376c8acaa/data/country-codes.csv"
