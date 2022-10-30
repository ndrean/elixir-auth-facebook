defmodule ElixirSdkFacebookHelper do
  defp into_atoms(strings) do
    for {k, v} <- strings, into: %{}, do: {String.to_atom(k), v}
  end

  # update a nested key
  defp parse(params, key \\ :picture) do
    params
    |> into_atoms()
    |> Map.update!(key, fn pic ->
      pic
      |> Jason.decode!()
      |> into_atoms()
    end)
  end
end
