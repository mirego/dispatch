defmodule Dispatch.AbsenceIO.RelevancyBooster do
  @moduledoc """
  All or nothing booster, if the person fullname is marked as absent on Absence.IO
  simply nullify the score.
  """

  alias Dispatch.AbsenceIO

  alias Dispatch.Utils.Normalization

  def apply_booster(user_relevancies, _options) do
    absent_fullnames = AbsenceIO.absent_fullnames()

    Enum.map(user_relevancies, &add_booster(&1, absent_fullnames))
  end

  defp add_booster(%{score: 0} = user_relevancy, _excluded_usernames), do: user_relevancy

  defp add_booster(user_relevancy, absent_fullnames) do
    is_absent = is_absent?(user_relevancy, absent_fullnames)
    booster = if is_absent, do: 0, else: 1

    Map.merge(user_relevancy, %{
      boosters: user_relevancy.boosters ++ [{:absence_io, booster}],
      score: user_relevancy.score * booster
    })
  end

  defp is_absent?(%{fullname: nil}, _absent_fullnames), do: true
  defp is_absent?(%{fullname: fullname}, absent_fullnames), do: Normalization.normalize(fullname) in absent_fullnames
end
