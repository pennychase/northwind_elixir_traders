import Config

database_home = System.get_env("SQLITE_DB_DIR") || ""

config :northwind_elixir_traders, NorthwindElixirTraders.Repo,
 database: database_home <> "northwind_elixir_traders_repo.db"
