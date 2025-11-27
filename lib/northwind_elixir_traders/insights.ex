defmodule NorthwindElixirTraders.Insights do
  import Ecto.Query
  alias NorthwindElixirTraders.{Repo, Product, Order, OrderDetail, Customer, Employee, Shipper, Supplier, Category}

  @tables [Customer, Employee, Shipper, Category, Supplier, Product, OrderDetail, Order]
  @m_tables @tables -- [Order, OrderDetail]

  @max_concurrency System.schedulers_online()
  @timeout 10_000

  # Queries and calculations for Order

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

  # Queries and calculations for Customer

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

  def query_customers_by_order_revenue, do: query_entity_by_order_revenue(Customer)

  def count_customers_orders(condition \\ :with), do: count_entity_orders(Customer, condition)

  # Can use to plot share of customers vs share of revenue:
  #   Insights.generate_customer_share_of_revenues_xy 
  #   |> Enum.each(fn {n, r} -> IO.puts("#{n}\t#{r}") end)
  # Copy and paste tab-separated result into Excel and create a scatter plot
  def generate_customer_share_of_revenues_xy, do: generate_entity_share_of_revenues_xy(Customer)

  # Generalized queries and calculations for all modules

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

  def calculate_top_n_entity_by_order_value(m, n \\ 5)
      when m in @m_tables and is_integer(n) and n >= 0 do
    if n == 0 do
      0
    else
      from(s in subquery(query_top_n_entity_by_order_revenue(m, n)),
          select: sum(s.revenue))
      |> Repo.one()
    end
  end

  def query_top_n_entity_by_order_revenue(m, n \\ 5)
      when m in @m_tables and is_integer(n) and n >= 0 do
    from(s in subquery(query_entity_by_order_revenue(m)),
        order_by: [desc: s.revenue], limit: ^n)
  end

  # Gini Coefficient

  def gini(m) when m in @m_tables do
    m
    |> generate_entity_share_of_revenues_xy()
    |> calculate_gini_coeff()
  end

  def generate_entity_share_of_revenues_xy(m) when m in @m_tables do
    0 .. count_entity_orders(m, :with)
    |> Task.async_stream(&{&1, calculate_top_n_entity_by_order_value(m, &1)})
    |> Enum.to_list()
    |> extract_task_results()
    |> normalize_xy()
  end

  def normalize_xy(xyl) when is_list(xyl) do
    {mxn, mxr} = 
      xyl |> Enum.reduce({0, 0}, fn {n, r}, {mxn, mxr} -> {max(n, mxn), max(r, mxr)} end)

    xyl
    |> Enum.map(fn {n, r} -> {n / mxn, r / mxr} end)
  end

  def extract_task_results(r) when is_list(r), do: Enum.map(r, &elem(&1, 1))

  def calculate_gini_coeff(xyl) when is_list(xyl) do
    xyl
    |> then(&Enum.zip(&1, tl(&1)))
    |> Enum.reduce(0.0, fn c, acc -> acc + calculate_chunk_area(c) end)
    |> Kernel.-(0.5)
    |> Kernel.*(2)
  end

  def calculate_chunk_area({{x1, y1}, {x2, y2}}) do
    {w, h} = {x2 - x1, y2 - y1}
    w * h * 0.5 + y1 * w
  end

  # Calculate share of revenues of the vital few and trivial many (default to 80/20 rule)

  def calculate_relative_revenue_share_of_entity_rows(m) do
    data =  from(s in subquery(query_entity_by_order_revenue(m)),
              order_by: [desc: s.revenue])
            |> Repo.all()
    total = Enum.sum_by(data, & &1.revenue)

    Enum.map(data, fn %{revenue: r} = x ->
      %{id: x.id, name: x.name, share: r / total} end)
  end

  def revenue_share_total_trivial_many(m, q \\ 0.8) do
    calculate_relative_revenue_share_of_entity_rows(m)
    |> Enum.reverse()
    |> helper_vital_trivial(m, q)
  end

  def revenue_share_total_vital_few(m, q \\ 0.2) do
    calculate_relative_revenue_share_of_entity_rows(m)
    |> helper_vital_trivial(m, q)
  end

  def helper_vital_trivial(data, m, q)
      when is_list(data) and m in @m_tables and is_number(q) and q >0 and q <= 1 do
    n =
      m
      |> count_entity_orders(:with)
      |> Kernel.*(q)
      |> round()
    data
    |> Enum.take(n)
    |> Enum.sum_by(& &1.share)
  end

  # Utilities

  def dollarize(cents) when is_number(cents), do: cents / 100

  # Benchmarking parallelism
  # Run in IEx (compute time per # processor and times relative to one processor):
  # orders = Repo.all(Order)
  # x = 1..(2*System.schedulers_online()) |> Enum.map(&{&1, Insights.parallel_benchmark(&1, 1000, orders)})
  # x_rel = Enum.map(x, fn {mc, t} -> {mc, t / Enum.max(Keyword.values(x)) |> Float.round(3)} end)

  def parallel_benchmark(mc, reps, orders) do
    :timer.tc(fn -> 
      Enum.map(1..1000, fn _ -> calculate_total_value_of_orders(orders, max_concurrency: mc) end)
    end)
    |> elem(0)
    |> Kernel./(reps)
  end



end