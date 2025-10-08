defmodule Utils.Changeset do
  import Ecto.Changeset

  def transcribe_errors(changeset, rgx \\ ~r/%{(\w+)}/) do  
    changeset 
    |> traverse_errors(fn {msg, opts} ->
      Regex.replace(rgx, msg, fn _s, g -> 
        opts 
        |> Keyword.get(String.to_existing_atom(g)) 
        |> to_string() 
        end)
      end)
  end

  def output_errors(changeset) do
    transcribed_errors = transcribe_errors(changeset)
    transcribed_errors
    |> Map.keys() 
    |> Enum.map(fn k -> {k, Enum.join(transcribed_errors[k], " and ")} end) 
    |> Map.new()
  end
  
end