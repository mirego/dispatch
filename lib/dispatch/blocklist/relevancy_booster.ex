defmodule Dispatch.Blocklist.RelevancyBooster do
  @moduledoc """
  All or nothing booster, if the username is present in the blocklist we
  simply nullify the score.
  """

  alias Dispatch.Blocklist

  def apply_booster(user_relevancies, options) do
    author_username = Keyword.get(options, :author_username)
    excluded_usernames = [author_username | Enum.map(Blocklist.users(), & &1.username)]

    Enum.map(user_relevancies, &add_booster(&1, excluded_usernames))
  end

  defp add_booster(%{score: 0} = user_relevancy, _excluded_usernames), do: user_relevancy

  defp add_booster(user_relevancy, excluded_usernames) do
    is_absent = user_relevancy.username in excluded_usernames
    booster = if is_absent, do: 0, else: 1

    Map.merge(user_relevancy, %{
      boosters: user_relevancy.boosters ++ [{:blocklist, booster}],
      score: user_relevancy.score * booster
    })
  end
end
