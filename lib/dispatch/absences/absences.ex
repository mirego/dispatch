defmodule Dispatch.Absences do
  alias Dispatch.Utils.Normalization

  def absent_fullnames do
    client().fetch_absents()
    |> Enum.filter(&absent_right_now?/1)
    |> Enum.map(&extract_fullname/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&Normalization.normalize/1)
  end

  defp absent_right_now?(%{start: starts, end: ends}), do: Timex.between?(Timex.now(), starts, ends, inclusive: true)

  defp extract_fullname(%ExIcal.Event{summary: " Out of Office - " <> fullname}), do: Normalization.normalize(fullname)
  defp extract_fullname(%ExIcal.Event{summary: "Out of Office - " <> fullname}), do: Normalization.normalize(fullname)
  defp extract_fullname(_), do: nil

  defp client, do: Application.get_env(:dispatch, Dispatch)[:absences_client]
end
