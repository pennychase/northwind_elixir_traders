# NorthwindElixirTraders

## Chapter 2 code to deed the database

alias NorthwindElixirTraders.{Repo,Category}; Repo.delete_all(Category); [[23, "Yolotronic Yoloroos", "Elixirs for the adventurous, daring, or plain reckless"], [42, "Swagalicious Swagaroonies", "Elixirs for those stylish, self-assured, and exuding confidence"], [47, "Metallic Metalloids", "Elixirs for the bold and edgy, with a hint of rebellious flair"], [48, "Rizzlicious Rizzoolas", "Elixirs for the charming, flavorful, and irresistibly attractive"]] |> Enum.map(&Enum.zip([:id, :name, :description], &1)) |> then(&Repo.insert_all(Category, &1)); Repo.all(Category)

