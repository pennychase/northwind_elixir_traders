# NorthwindElixirTraders

## Chapter 2 code to seed the database

alias NorthwindElixirTraders.{Repo,Category}; Repo.delete_all(Category); [[23, "Yolotronic Yoloroos", "Elixirs for the adventurous, daring, or plain reckless"], [42, "Swagalicious Swagaroonies", "Elixirs for those stylish, self-assured, and exuding confidence"], [47, "Metallic Metalloids", "Elixirs for the bold and edgy, with a hint of rebellious flair"], [48, "Rizzlicious Rizzoolas", "Elixirs for the charming, flavorful, and irresistibly attractive"]] |> Enum.map(&Enum.zip([:id, :name, :description], &1)) |> then(&Repo.insert_all(Category, &1)); Repo.all(Category)


## Chapter 10 code to seed the database

%{p: p, c: c, s: s} = "H4sIAAAAAAAAA3XSQU8TQRQH8HZplVCIGkRNuDwuBA+bUBoPHEwslWIaaggl8WJi3k4fZcrszDgz69Kz3vkOcPDGh+BLeJbvgAcTE2ebyABxT5vdffN+u+/9v7pKpTKTV5nw16i4ifKID7Ga1ySmlPoHy3vKuritFUMx0Y4z2DPqC7dcSRsOROHA47ZhKAnaxvFDZM6O86ou+teL8gf3+7/YEph2FLxXLu4cEVmCgTaEw7yWSe6KkoUmOC4hho1X6zDKGwwdjZSZfJp2qmvDGXXfLF5fnn5c+5U3bKa14GSmr4N56xOfbwt+wg2oQ+jjJKH4HaHgchTIJ01IlHOCvNpqrUO6e5eNbtjWH33+Y+51KTsT2GcfMElwnI1g7erbGWiSQ4++DOrDJmhOjMqs7+r3z52Lp3etKFi1YC31eep3tU+ahCDpiqHiJFDzTfBb8n9XPtLEr2yz1KoHa6GXyWPokYNuRiIYs/+G+P/+GN8bmg+KLQ/io30cGoXsCFZhUBa+lQODcuDQwFtutbIorC9vs8+ZT6wrMjv+C8QJZCn0AgAA" |> Base.decode64!() |> :zlib.gunzip() |> :erlang.binary_to_term()
Enum.map(s, &Supplier.changeset(%Supplier{}, &1) |> Repo.insert)
Enum.map(c, &Category.changeset(%Category{}, &1) |> Repo.insert)
Enum.map(p, &Product.changeset(%Product{}, &1) |> Repo.insert)