defmodule Dispatch.Repositories.Contributors do
  alias Dispatch.SelectedUser
  alias Dispatch.Utils.{Random, TimeHelper}

  @doc """
  Loop through each contributors and randomly select one based on his relevancy

  Example:
  Given a list of 3 contributors

  %{username: "John", relevancy: 1}
  %{username: "Jane", relevancy: 7}
  %{username: "joe", relevancy: 2}

  For a relevancy total of 10

  So contributors will be selected based on the random pick index like this:

  John: 1
  Jane: 2 to 8
  Joe: 9 and 10
  """
  def select(nil), do: []
  def select([]), do: []

  def select(contributors) do
    random_pick_index =
      contributors
      |> Enum.reduce(0, fn %{relevancy: relevancy}, acc -> relevancy + acc end)
      |> Random.uniform()

    Enum.reduce_while(contributors, random_pick_index, fn contributor, acc ->
      acc = acc - contributor.relevancy

      if acc <= 0 do
        {:halt,
         [
           %SelectedUser{
             username: contributor.username,
             type: "contributor",
             metadata: %{
               recent_commit_count: contributor.recent_commit_count,
               total_commit_count: contributor.total_commit_count
             }
           }
         ]}
      else
        {:cont, acc}
      end
    end)
  end

  @doc """
  Calculate the relevancy of the contributor

  Take the all time total commits and add the last three months commits

  Weekly Hash (weeks array):

  w - Start of the week, given as a Unix timestamp.
  a - Number of additions
  d - Number of deletions
  c - Number of commits

  More at https://developer.github.com/v3/repos/statistics/#get-contributors-list-with-additions-deletions-and-commit-counts
  """
  def calculate_relevancy(%{"total" => total, "weeks" => weeks}) do
    recent_commit_count = retrieve_relevant_week_commits(weeks)
    relevancy = total + recent_commit_count

    {total, recent_commit_count, relevancy}
  end

  defp retrieve_relevant_week_commits(weeks) do
    starting_week = TimeHelper.unix_beginning_of_week(relevant_activity_days())

    Enum.reduce(weeks, 0, fn
      %{"w" => week, "c" => count}, acc when week >= starting_week ->
        acc + count

      _, acc ->
        acc
    end)
  end

  def relevant_activity_days, do: Application.get_env(:dispatch, __MODULE__)[:relevant_activity_days]
end
