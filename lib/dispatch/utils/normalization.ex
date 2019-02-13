defmodule Dispatch.Utils.Normalization do
  def normalize(string) do
    string
    |> String.normalize(:nfd)
    |> String.replace(~r/[^A-z\s]/u, "")
    |> String.trim()
    |> String.downcase()
  end
end
