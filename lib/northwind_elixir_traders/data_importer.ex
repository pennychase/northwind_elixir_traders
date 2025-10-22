defmodule NorthwindElixirTraders.DataImporter do
  require Logger
  alias NorthwindElixirTraders.Repo

  @name :nt 
  @database ((System.get_env("SQLITE_DB_HOME") || "") <> "NorthwindTraders-original.db")

  # Start the original Northwind Traders database
  def start() do
    if is_nil(Process.whereis(@name)),
      do: Repo.start_link(name: @name, database: @database)
  end
  
  # Query the oroiinal Northwinds Traders database, ensuring that 
  # it's the active database. and then making our Repo the active database
  def switch(name) when name in [@name, Repo] do
    try do
      if name == @name, do: start()
      Repo.put_dynamic_repo(name)
      Logger.debug("Switched to #{name}")
      {:ok, Repo.get_dynamic_repo()}
    catch
      _ -> 
          Logger.debug("Error: could not switchto #{name}")
          {:error, Repo.get_dynamic_repo()}
    end
  end

  def switch() do
    case Repo.get_dynamic_repo() do
      @name -> switch(Repo)
      _ -> switch(@name)
    end
  end

  def nt_query(sql) when is_bitstring(sql) do
    switch(:nt)
    result = Repo.query(sql)
    switch()
    result
  end

  # Helper functions to transform table names and column names into our conventions
  def singularize(plural) when is_bitstring(plural) do
    ending = String.slice(plural, -3 .. -1)

    if ending == "ies" do
      String.replace(plural, ending, "y")
    else
      String.trim(plural, "s")
    end
  end

  def pluralize(singular) when is_bitstring(singular) do
    last_char = String.last(singular)

    case last_char do
      "y" -> String.trim(singular, last_char) <> "ies"
      _ -> singular <> "s"
    end
  end

  # Retrieve table names
  def table_names() do
    sql = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"

    case nt_query(sql) do
      {:ok, r} -> {:ok, r |> Map.get(:rows) |> List.flatten()}
      {_, r} -> {:error, r}
    end
  end

  # Retrieve all the data from a table
  def select_all(table) when is_bitstring(table) do
    case table_names() do
      {:ok, nt_table_names} when is_list(nt_table_names) ->
        if table not in nt_table_names do
          {:error, "No table named #{table} in #{@database}"}
        else
          query_actually(table)
        end
      {:error, r} -> {:error, r}
    end        
  end

  def query_actually(table) do
    sql = "SELECT * FROM #{table}"
    {s, r} = nt_query(sql)

    case {s, r} do
      {:ok, r} ->
        cols = treat_columns(r.columns, table)
        must_treat_dates? =
          [:birth_date, :date] 
          |> Enum.map(&Enum.member?(cols, &1))
          |> Enum.reduce(false, fn x, acc -> acc or x end)

        res =
          r.rows
          |> Enum.map(&Enum.zip(cols, &1))
          |> Enum.map(&Map.new/1)
        res = if must_treat_dates?, do: Enum.map(res, &treat_dates/1), else: res

        {:ok, res}
      {:error, r} -> {:error, r}
    end
  end

  # Translate original column names into our conventions
  def treat_columns(cols, table) do
    singular = singularize(table)

    Stream.map(cols, fn c ->
        if String.contains?(c, singular), do: String.replace(c, singular, ""), else: c end)
      |> Stream.map(&Macro.underscore/1)
      |> Stream.map(&String.to_atom/1)
      |> Enum.to_list()
  end

  # Translate string representations of SQL DATE and DATETIME into Elixir types.
  # :birth_date in Employee is translated into a Date
  # :date in Order is translated into a DateTime by adding the time component
  def treat_dates(m) when is_map(m) do
    mk = Map.keys(m)

    case {:birth_date in mk, :date in mk} do
      {true, _} -> %{m | birth_date: Date.from_iso8601!(m.birth_date)}
      {_, true} -> %{m | date: (m.date <> "T12:00:00Z") |> DateTime.from_iso8601() |> elem(1)}
      {false, false} -> m
    end
  end

  # Insert all the rows from a given table. Repo.insert_all/2 fails because timestamps are 
  # not automatically created (since it's designed toinsert data in bulk at high effciency)

  # Helper to create empty struct (corresponding to schema) from table name in :nt
  def table_to_internals(table) when is_bitstring(table) do
    app = __MODULE__ |> Module.split() |> hd
    module =
      singularize(table)
      |> then(&List.insert_at([app], -1, &1))
      |> Enum.map(&String.to_existing_atom/1) |> Module.concat()

      %{module_name: module, empty_struct: struct(module)}
  end

  # Insert all the rows of table from :nt
  def insert_all_from(table) do
    
    %{module_name: modname, empty_struct: estruct} = table_to_internals(table)
    {:ok, data} = select_all(table)
    changeset = fn m -> apply(modname, :changeset, [estruct, m]) end

    data
    |> Enum.map(&changeset.(&1))
    |> Enum.map(&Repo.insert/1)
  end

  # Import data from tables that have been modeled, but not yet imported

  def get_application() do
    __MODULE__ 
    |> Module.split() 
    |> hd() 
    |> List.wrap() 
    |> Module.concat()
    |> Application.get_application()
  end

  def get_modules() do
    get_application()
    |> :application.get_key(:modules)
    |> elem(1)
    |> Enum.map(&(Module.split(&1) |> tl))
    |> List.flatten()
  end

  def get_tables_to_import() do
    plurals = 
      get_modules()
      |> Enum.map(&pluralize/1)

    table_names()
      |> elem(1)
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(plurals)) 
      |> MapSet.to_list()
  end

  # Naive approach to importing tables into Repo
  # def import_all_modeled() do
  #   get_tables_to_import()
  #   |> Enum.map(&insert_all_from/1)
  # end

  def import_all_modeled() do
    prioritize()
    |> Enum.map(&model_to_table/1)
    |> Enum.map(&insert_all_from/1)
  end

  # Determine order in which tables should be loaded

  def get_modules_of_modeled_tables() do
    get_tables_to_import() 
    |> Enum.map(&table_to_internals/1) 
    |> Enum.map(&Map.get(&1, :module_name))
  end

  def outbound(module_name) when is_atom(module_name) do
    module_name
    |> struct()
    |> Map.keys()
    |> Enum.filter(&String.contains?(Atom.to_string(&1), "_id"))
  end

  def make_dependency_map() do
    get_modules_of_modeled_tables()
    |> Enum.map(&{&1, outbound(&1)})
    |> Map.new()
  end

  def gather(erd) when is_map(erd) do
    erd 
    |> Enum.map(fn {k, vl} -> 
      {k, Enum.map(vl, fn vv -> 
        {vv, Map.get(erd, vv)} end) 
      |> Map.new()} end) 
    |> Map.new()
  end

  def model_to_table(model) when is_atom(model) do
    model|> Module.split()
    |> List.last()
    |> pluralize()
  end

  def prioritize() do
    make_dependency_map()
    |> gather()
    |> Enum.map(fn {k, v} -> {k, List.flatten([Map.values(v) | Map.keys(v)])} end)
    |> Enum.sort_by(fn {_, dependencies} -> length(dependencies) end)
    |> Enum.map(&elem(&1,0))
  end

  # Functions to analyze imports

  def tally() do
    prioritize()
    |> Enum.map(&({&1, Repo.aggregate(&1, :count)}))
    |> Map.new
  end

  def get_unique_errors(records) do
    records
    |> List.flatten 
    |> Enum.filter(&(elem(&1, 0) != :ok)) 
    |> Enum.map(&elem(&1, 1)) 
    |> Enum.map(&Map.get(&1, :errors)) 
    |> Enum.map(fn [{k, {msg, _}}] -> {k, msg} end) |> Enum.uniq
  end


end