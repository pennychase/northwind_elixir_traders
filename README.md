# NorthwindElixirTraders

Code to recreate the data from Chapter 2: 

alias NorthwindElixirTraders.{Repo,Category}
Repo.delete_all(Category)
d = [ [23, "Yolotronic Yoloroos", "Elixirs for the adventurous, daring, or plain reckless"], [42, "Swagalicious Swagaroonies", "Elixirs for those stylish, self-assured, and exuding confidence"], [47, "Metallic Metalloids", "Elixirs for the bold and edgy, with a hint of rebellious flair"], [48, "Rizzlicious Rizzoolas", "Elixirs for the charming, flavorful, and irresistibly attractive"]]
d |> Enum.map(&Enum.zip([:id, :name, :description], &1)) |> Enum.each(&Repo.insert(struct(Category, &1)))

This was the original code in the book, but it doesn't work if constraints were already created:
d |> Enum.map(&Enum.zip([:id, :name, :description], &1)) |> then(&Repo.insert_all(Category, &1))
Repo.all(Category)


Snippets for creating tables:

%Product{}
|> Product.changeset(%{name: "Mace of Molag Bal", unit: "1 piece", price: 1280, category_id: 1})
|> Repo.insert()

%Product{}
|> Product.changeset(%{name: "Auriel's Bow", unit: "1 piece", price: 999.90, category_id: 1})
|> Repo.insert()

%Product{}
|> Product.changeset(%{name: "BFG-899", unit: "1 piece", price: 99.99, category_id: 1})
|> Repo.insert()

%Category{}
|> Category.changeset(%{name: "Overkill Instruments"})
|> Repo.insert()

%Employee{}
|> Employee.changeset(%{first_name: "Gulliver", last_name: "Foyle", birth_date: ~D[2094-09-14]})
|> Repo.insert()

%Employee{}
|> Employee.changeset(%{first_name: "Ben", last_name: "Reich", birth_date: ~D[1976-02-15]})
|> Repo.insert()

%Employee{}
|> Employee.changeset(%{first_name: "Hideoki", last_name: "Kojimaki", birth_date: ~D[1964-09-25]})
|> Repo.insert()

%Supplier{}
|> Supplier.changeset(%{name: "Hakkinen Spice Industries LLC"})
|> Repo.insert()

%Supplier{}
|> Supplier.changeset(%{name: "Acme Inc."})
|> Repo.insert()

%Supplier{}
|> Supplier.changeset(%{name: "Wumpus Archery Supplies Co."})
|> Repo.insert()