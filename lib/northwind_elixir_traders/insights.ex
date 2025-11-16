defmodule NorthwindElixirTraders.Insights do
  import Ecto.Query
  alias NorthwindElixirTraders.Insights
  alias NorthwindElixirTraders.{Repo, Product, Order, OrderDetail}

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