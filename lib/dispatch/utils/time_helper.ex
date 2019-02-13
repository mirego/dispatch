defmodule Dispatch.Utils.TimeHelper do
  def unix_beginning_of_week(days_to_substract) do
    Timex.now()
    |> Timex.subtract(Timex.Duration.from_days(days_to_substract))
    |> Timex.beginning_of_week(:sun)
    |> Timex.to_unix()
  end
end
