defmodule NorthwindElixirTraders.Insights.Gini do
  import Ecto.Query
  alias NorthwindElixirTraders.{Repo, Product, Order, OrderDetail, Customer, Employee, Shipper, Supplier, Category}

  @tables [Customer, Employee, Shipper, Category, Supplier, Product, OrderDetail, Order]
  @m_tables @tables -- [Order, OrderDetail]

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

  def normalize_xy(xyl) when is_list(xyl) do
    {mxn, mxr} = 
      xyl |> Enum.reduce({0, 0}, fn {n, r}, {mxn, mxr} -> {max(n, mxn), max(r, mxr)} end)

    xyl
    |> Enum.map(fn {n, r} -> {n / mxn, r / mxr} end)
  end

  def extract_task_results(r) when is_list(r), do: Enum.map(r, &elem(&1, 1))

  # Can use to create data to plot share of entity vs share of revenue:
  #   Insights.generate_entity_share_of_revenues_xy(m)
  #   |> Enum.each(fn {n, r} -> IO.puts("#{n}\t#{r}") end)
  # Copy and paste tab-separated result into Excel and create a scatter plot
  def generate_entity_share_of_revenues_xy(m) when m in @m_tables do
    0 .. count_entity_orders(m, :with)
    |> Task.async_stream(&{&1, calculate_top_n_entity_by_order_value(m, &1)})
    |> Enum.to_list()
    |> extract_task_results()
    |> normalize_xy()
  end

  def calculate_chunk_area({{x1, y1}, {x2, y2}}) do
    {w, h} = {x2 - x1, y2 - y1}
    w * h * 0.5 + y1 * w
  end

  # xyl is normalized, e.g., output of generate_entity_share_of_revenues_xy/1
  def calculate_gini_coeff(xyl) when is_list(xyl) do
    xyl
    |> then(&Enum.zip(&1, tl(&1)))
    |> Enum.reduce(0.0, fn c, acc -> acc + calculate_chunk_area(c) end)
    |> Kernel.-(0.5)
    |> Kernel.*(2)
  end

  def gini(m) when m in @m_tables do
    m
    |> generate_entity_share_of_revenues_xy()
    |> calculate_gini_coeff()
  end

end