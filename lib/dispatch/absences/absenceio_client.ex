defmodule Dispatch.Absences.AbsenceIOClient do
  @behaviour Dispatch.Absences.ClientBehaviour

  def fetch_absents do
    ical_feed_url()
    |> HTTPoison.get()
    |> fetch_absents()
  end

  defp fetch_absents({:ok, response}) do
    response
    |> Map.get(:body)
    |> ExIcal.parse()
  end

  defp fetch_absents(_), do: []
  defp ical_feed_url, do: Application.get_env(:dispatch, __MODULE__)[:ical_feed_url]
end
