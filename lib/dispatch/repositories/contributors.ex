defmodule Dispatch.Repositories.Contributors do
  alias Dispatch.Repositories.Contributor
  alias Dispatch.SelectedUser
  alias Dispatch.Utils.Random
  alias Dispatch.Utils.TimeHelper

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
    total = Enum.reduce(contributors, 0, fn %{relevancy: relevancy}, acc -> relevancy + acc end)
    random_pick_index = Random.uniform(total)

    Enum.reduce_while(contributors, random_pick_index, &process_contributor/2)
  end

  defp process_contributor(%Contributor{username: username, relevancy: relevancy, recent_commit_count: recent_commit_count, total_commit_count: total_commit_count}, acc) do
    acc = acc - relevancy

    if acc <= 0 do
      {:halt,
       [
         %SelectedUser{
           username: username,
           type: "contributor",
           metadata: %{
             recent_commit_count: recent_commit_count,
             total_commit_count: total_commit_count
           }
         }
       ]}
    else
      {:cont, acc}
    end
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
    starting_week =
      :dispatch
      |> Application.get_env(Dispatch.Repositories.Contributors)
      |> Keyword.get(:relevant_activity_days)
      |> TimeHelper.unix_beginning_of_week()

    Enum.reduce(weeks, 0, &process_week(&1, &2, starting_week))
  end

  defp process_week(%{"w" => week, "c" => count}, acc, starting_week) when week >= starting_week, do: acc + count
  defp process_week(_, acc, _), do: acc
end
