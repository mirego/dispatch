defmodule Dispatch.Repositories do
  alias Dispatch.Repositories.Contributors

  defmodule Contributor do
    @enforce_keys [:username, :relevancy, :recent_commit_count, :total_commit_count]
    defstruct username: nil, relevancy: nil, recent_commit_count: nil, total_commit_count: nil
  end

  defmodule User do
    @enforce_keys [:username, :fullname]
    defstruct username: nil, fullname: nil
  end

  def requestable_users(repo) do
    client().fetch_requestable_users(repo)
  end

  def contributors(repo, requestable_usernames) do
    repo
    |> client().fetch_contributors()
    |> Enum.filter(&Enum.member?(requestable_usernames, &1.username))
    |> relevant_contributors()
  end

  def request_reviewers(repo, pull_request_number, reviewers) do
    client().request_reviewers(repo, pull_request_number, reviewers)
  end

  def create_request_comment(repo, pull_request_number, reviewers) do
    client().create_request_comment(repo, pull_request_number, reviewers)
  end

  def relevant_contributors(contributors), do: Contributors.select(contributors)

  defp client, do: Application.get_env(:dispatch, Dispatch)[:repositories_client]
end
