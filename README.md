# NorthwindElixirTraders

Snippets for creating tables:

%Product{}
|> Product.changeset(%{name: "Mace of Molag Bal", unit: "1 piece", price: 1280, category_id: 1})
|> Repo.insert()

%Products{}
|> Product.changeset(%{name: "Auriel's Bow", unit: "1 piece", price: 999.90, category_id: 1})
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