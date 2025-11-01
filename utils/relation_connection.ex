defmodule Utils.RelationConnection do

  def related(table, rel1, rel2) do
    table
    |> Enum.map(&Map.take(&1, [rel1, rel2]))
    |> Enum.reduce(%{}, fn %{^rel1 => r1, ^rel2 => r2}, acc ->
        {_, acc} = 
          Map.get_and_update(acc, r1, fn val ->
            if is_nil(val) do
              {nil, [r2]}
            else
              {val, (val ++ [r2]) |> Enum.sort |> Enum.uniq}
            end
          end)
        acc
        end)
  end

  def sizes(related) do
    related
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sort(:desc)
  end

  # Define condition as an anonymous function, e.g. fn x -> x == 1 end
  def counts(related, condition) do
    related
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.count(&condition.(&1))
  end
end
  