defmodule Dispatch.Repositories.GitHubClient do
  @moduledoc """
  Expose functions to query everything related to repositories using GitHub REST and GraphQL APIs.
  """
  @behaviour Dispatch.Repositories.ClientBehaviour

  alias Dispatch.Repositories.Contributor
  alias Dispatch.Repositories.Contributors
  alias Dispatch.Repositories.RequestComments
  alias Dispatch.Repositories.User

  @base_url "https://api.github.com"
  @retry_count 10

  @doc """
  Returns whether GitHub REST API is up and responding correctly.
  """
  def ping do
    @base_url
    |> HTTPoison.get(rest_headers())
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200}} -> :ok
      _ -> :error
    end
  end

  @doc """
  Given a repo, a pull request and a list of reviewers, request them as reviewers using the REST API.
  """
  def request_reviewers(repo, pull_request_number, reviewers) do
    url = "/repos/#{repo}/pulls/#{pull_request_number}/requested_reviewers"

    body =
      Poison.encode!(%{
        reviewers: Enum.map(reviewers, & &1.username)
      })

    (@base_url <> url)
    |> HTTPoison.post(body, rest_headers())
    |> case do
      {:ok, %HTTPoison.Response{status_code: 201}} -> :ok
      _ -> :error
    end
  end

  @doc """
  Given a repo, a pull request and a list of reviewers, create a comment documenting why the reviewers were chosen using the REST API.
  """
  def create_request_comment(repo, pull_request_number, reviewers) do
    url = "/repos/#{repo}/issues/#{pull_request_number}/comments"

    body =
      Poison.encode!(%{
        body: RequestComments.request_comment(reviewers)
      })

    (@base_url <> url)
    |> HTTPoison.post(body, rest_headers())
    |> case do
      {:ok, %HTTPoison.Response{status_code: 201}} -> :ok
      _ -> :error
    end
  end

  @doc """
  Returns all users that can be selected as reviewwers in a repository.
  """
  def fetch_requestable_users(repo), do: fetch_requestable_users(repo, 0)

  defp fetch_requestable_users(_, try_count) when try_count > @retry_count, do: []

  defp fetch_requestable_users(repo, try_count) do
    [repo_owner, repo_name] = String.split(repo, "/")

    query = """
    query($repoOwner: String!, $repoName: String!) {
      repository(owner: $repoOwner, name: $repoName) {
        assignableUsers(first: 100) {nodes {login name}}
      }
    }
    """

    body =
      Poison.encode!(%{
        query: query,
        variables: %{
          repoOwner: repo_owner,
          repoName: repo_name
        }
      })

    (@base_url <> "/graphql")
    |> HTTPoison.post(body, graphql_headers())
    |> case do
      {:ok, %{status_code: 200, body: body}} ->
        map_requestable_users_response(body)

      _ ->
        :timer.sleep(retry_delay())
        fetch_requestable_users(repo, try_count + 1)
    end
  end

  defp map_requestable_users_response(body) do
    body
    |> Poison.decode()
    |> map_requestable_users()
  end

  defp map_requestable_users({:ok, data}) do
    data
    |> get_in(["data", "repository", "assignableUsers", "nodes"])
    |> Enum.map(fn %{"login" => username, "name" => fullname} -> %User{username: username, fullname: fullname} end)
  end

  defp map_requestable_users(_), do: []

  def fetch_contributors(repo) do
    fetch_contributors(repo, 0)
  end

  defp fetch_contributors(_, try_count) when try_count > @retry_count, do: []

  defp fetch_contributors(repo, try_count) do
    (@base_url <> "/repos/#{repo}/stats/contributors")
    |> HTTPoison.get(rest_headers())
    |> case do
      {:ok, %{status_code: 200, body: body}} ->
        map_contributors_response(body)

      _ ->
        :timer.sleep(retry_delay())
        fetch_contributors(repo, try_count + 1)
    end
  end

  defp map_contributors_response(body) do
    body
    |> Poison.decode()
    |> map_contributors()
  end

  defp map_contributors({:ok, contributors}) when is_list(contributors) do
    contributors
    |> Enum.map(fn
      %{"author" => %{"login" => username}} = contributor ->
        {total, recent_commit_count, relevancy} = Contributors.calculate_relevancy(contributor)

        %Contributor{username: username, relevancy: relevancy, recent_commit_count: recent_commit_count, total_commit_count: total}

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp map_contributors(_), do: []

  defp retry_delay, do: Application.get_env(:dispatch, __MODULE__)[:retry_delay]
  defp access_token, do: Application.get_env(:dispatch, __MODULE__)[:access_token]
  defp graphql_headers, do: [{"Authorization", "bearer #{access_token()}"}]
  defp rest_headers, do: [{"Authorization", "token #{access_token()}"}]
end
