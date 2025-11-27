defmodule NorthwindElixirTraders.Insights do
  import Ecto.Query
  alias NorthwindElixirTraders.Insights
  alias NorthwindElixirTraders.{Repo, Product, Order, OrderDetail, Customer, Employee, Shipper, Supplier, Category}

  @tables [Customer, Employee, Shipper, Category, Supplier, Product, OrderDetail, Order]
  @m_tables @tables -- [Order, OrderDetail]

  @max_concurrency System.schedulers_online()
  @timeout 10_000

  def query_order_details_by_order(order_id) do
    OrderDetail
    |> join(:inner, [od], p in Product, on: od.product_id == p.id)
    |> where([od], od.order_id == ^order_id)
  end

  def query_order_detail_values(order_id) do
    order_id
    |> query_order_details_by_order()
    |> select([od, p], od.quantity * p.price)
  end

  def query_order_total_value(order_id) do
    order_id
    |> query_order_details_by_order()
    |> select([od, p], sum(od.quantity * p.price))
  end

  def calculate_order_value(%Order{id: order_id}), do: calculate_order_value(order_id)

  def calculate_order_value(order_id) do
    order_id
    |> query_order_total_value()
    |> Repo.one()
  end

  def calculate_total_value_of_orders(orders, opts \\ [max_concurrency: @max_concurrency])
      when is_list(orders) and is_list(opts) do
    mc =
      if Keyword.has_key?(opts, :max_concurrency) do
        Keyword.get(opts, :max_concurrency)
      else
        @max_concurrency
      end

    Task.async_stream(orders, &calculate_order_value/1, ordered: false, timeout: @timeout, max_concurreny: mc)
    |> Enum.to_list()
    |> Enum.sum_by(&elem(&1, 1))
  end

  def list_top_n_customers_by_order_count(n \\ 5) when is_integer(n) do
    Customer
    |> join(:inner, [c], o in assoc(c, :orders)) |> group_by([c, o], c.id)
    |> select([c, o], %{id: c.id, name: c.name, num_orders: count(o.id)})
    |> order_by([c, o], desc: count(o.id))
    |> limit(^n)
    |> Repo.all
  end

  def query_orders_by_customer(%Customer{id: customer_id}),
    do: query_orders_by_customer(customer_id)

  def query_orders_by_customer(customer_id) when not is_map(customer_id) do
    from(o in Order, join: c in Customer, on: o.customer_id == c.id,
      where: o.customer_id == ^customer_id, select: o)
  end

  def query_top_n_customers_by_order_revenue(n \\ 5) do
    from(s in subquery(query_customers_by_order_revenue()),
      order_by: [desc: s.revenue], limit: ^n)
  end

  def calculate_top_n_customers_by_order_value(n \\ 5)
        when is_integer(n) and n >= 0 do
    if n == 0 do
      0.0
    else 
      from(s in subquery(query_top_n_customers_by_order_revenue(n)),
        select: sum(s.revenue)) |> Repo.one()
    end
  end

  def list_customers_by_order_revenue do
    from(s in subquery(query_customers_by_order_revenue()),
      order_by: [desc: s.revenue]) |> Repo.all()
  end

  def count_customers_with_revenues do
    from(s in subquery(query_customers_by_order_revenue()),
      where: s.revenue > 0, select: count(s.id)) |> Repo.one()
  end

  def query_customers_by_order_revenue do
    from(c in Customer,
      join: o in assoc(c, :orders),
      join: od in assoc(o, :order_details),
      join: p in assoc(od, :product),
      group_by: c.id, select: %{id: c.id, name: c.name, revenue: sum(od.quantity * p.price)})
  end

  def count_customers_orders(condition \\ :with), do: count_entity_orders(Customer, condition)

  def normalize_xy(xyl) when is_list(xyl) do
    {mxn, mxr} = 
      xyl |> Enum.reduce({0, 0}, fn {n, r}, {mxn, mxr} -> {max(n, mxn), max(r, mxr)} end)

    xyl
    |> Enum.map(fn {n, r} -> {n / mxn, r / mxr} end)
  end

  def extract_task_results(r) when is_list(r), do: Enum.map(r, &elem(&1, 1))

  # Use to create data to plot share of customers vs share of revenue
  # Call as: 
  #   Insights.generate_customer_share_of_revenues_xy 
  #   |> Enum.each(fn {n, r} -> IO.puts("#{n}\t#{r}") end)
  # Copy and paste tab-separated result into Excel and create a scatter plot
  def generate_customer_share_of_revenues_xy do
    0 .. count_customers_orders(:with)
    |> Task.async_stream(&{&1, calculate_top_n_customers_by_order_value(&1)})
    |> Enum.to_list()
    |> extract_task_results()
    |> normalize_xy()
  end

  def calculate_chunk_area({{x1, y1}, {x2, y2}}) do
    {w, h} = {x2 - x1, y2 - y1}
    w * h * 0.5 + y1 * w
  end

  def compute_gini() do
    data = generate_customer_share_of_revenues_xy()
    area =
      data 
      |> Enum.zip(tl(data))
      |> Enum.reduce(0.0, fn c, acc -> acc + calculate_chunk_area(c) end)
      |> Kernel.-(0.5)
    2 * area
  end

  # Generalize analyses to all entities

  def count_entity_orders(m, condition \\ :with)
      when m in @m_tables and condition in [:with, :without] do
    count_with =
      from(x in m)
      |> join(:inner, [x], o in assoc(x, :orders))
      |> select([x], x.id)
      |> distinct(true)
      |> Repo.aggregate(:count)

    case condition do
      :with -> count_with
      :without -> Repo.aggregate(m, :count) - count_with
    end      
  end

  def query_entity_by_order_revenue(m) when m in [Supplier, Category] do
    from(x in m,
      join: p in assoc(x, :products),
      join: od in assoc(p, :order_details),
      group_by: x.id,
      select: %{id: x.id, name: x.name, revenue: sum(od.quantity * p.price)})
  end

  def query_entity_by_order_revenue(m) when m == Product do
    from(x in m,
      join: od in assoc(x, :order_details),
      group_by: x.id,
      select: %{id: x.id, name: x.name, revenue: sum(od.quantity * x.price)})
  end

  def query_entity_by_order_revenue(m) when m in @m_tables do
    query =
      from(x in m,
        join: o in assoc(x, :orders),
        join: od in assoc(o, :order_details),
        join: p in assoc(od, :product),
        group_by: x.id,
        select: %{id: x.id, revenue: sum(od.quantity * p.price)})
    if m == Employee do
      select_merge(query, [x, o, od, p],
        %{name: fragment("? || ' ' || ?", x.last_name, x.first_name)})
    else
      select_merge(query, [x, o, od, p], %{name: x.name})
    end
  end

  def dollarize(cents) when is_number(cents), do: cents / 100

  # Benchmarking parallelism
  # Run in IEx (compute time per # processor and times relative to one processor):
  # orders = Repo.all(Order)
  # x = 1..(2*System.schedulers_online()) |> Enum.map(&{&1, Insights.parallel_benchmark(&1, 1000, orders)})
  # x_rel = Enum.map(x, fn {mc, t} -> {mc, t / Enum.max(Keyword.values(x)) |> Float.round(3)} end)

  def parallel_benchmark(mc, reps, orders) do
    :timer.tc(fn -> 
      Enum.map(1..1000, fn _ -> Insights.calculate_total_value_of_orders(orders, max_concurrency: mc) end)
    end)
    |> elem(0)
    |> Kernel./(reps)
  end



end