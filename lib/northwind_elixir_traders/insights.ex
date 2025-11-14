defmodule NorthwindElixirTraders.Insights do
  import Ecto.Query
  alias NorthwindElixirTraders.{Repo, Product, Order, OrderDetail}

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
  
end