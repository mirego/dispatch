defmodule Dispatch.Repositories.GitHubClient do
  @moduledoc """
  Expose functions to query everything related to repositories using GitHub REST and GraphQL APIs.
  """

  @behaviour Dispatch.Repositories.ClientBehaviour

  alias Dispatch.Repositories.{Contributor, Contributors, RequestComments, User}

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
  def request_reviewers(_, _, []), do: :ok

  def request_reviewers(repo, pull_request_number, reviewers) do
    url = "/repos/#{repo}/pulls/#{pull_request_number}/requested_reviewers"

    with {:ok, body} <- Jason.encode(%{reviewers: Enum.map(reviewers, & &1.username)}),
         {:ok, %HTTPoison.Response{status_code: 201}} <- HTTPoison.post(@base_url <> url, body, rest_headers()) do
      :ok
    else
      _ -> :error
    end
  end

  @doc """
  Given a repo, a pull request and a list of reviewers, create a comment documenting why the reviewers were chosen using the REST API.
  """
  def create_request_comment(_, _, []), do: :ok

  def create_request_comment(repo, pull_request_number, reviewers) do
    url = "/repos/#{repo}/issues/#{pull_request_number}/comments"

    with comment <- RequestComments.request_comment(reviewers),
         {:ok, body} <- Jason.encode(%{body: comment}),
         {:ok, %HTTPoison.Response{status_code: 201}} <- HTTPoison.post(@base_url <> url, body, rest_headers()) do
      :ok
    else
      _ -> :error
    end
  end

  @doc """
  Returns all users that can be selected as reviewwers in a repository.
  """
  def fetch_requestable_users(repo, try_count \\ 0)

  def fetch_requestable_users(_, try_count) when try_count > @retry_count do
    []
  end

  def fetch_requestable_users(repo, try_count) do
    [repo_owner, repo_name] = String.split(repo, "/")

    query = """
    query($repoOwner: String!, $repoName: String!) {
      repository(owner: $repoOwner, name: $repoName) {
        assignableUsers(first: 100) {nodes {login name}}
      }
    }
    """

    request = %{
      query: query,
      variables: %{
        repoOwner: repo_owner,
        repoName: repo_name
      }
    }

    with {:ok, body} <- Jason.encode(request),
         {:ok, %{status_code: 200, body: body}} <- HTTPoison.post(@base_url <> "/graphql", body, graphql_headers()) do
      map_requestable_users(body)
    else
      _ ->
        :timer.sleep(retry_delay())
        fetch_requestable_users(repo, try_count + 1)
    end
  end

  defp map_requestable_users(body) do
    body
    |> Jason.decode()
    |> case do
      {:ok, data} when is_map(data) ->
        data
        |> get_in(["data", "repository", "assignableUsers", "nodes"])
        |> Enum.map(fn %{"login" => username, "name" => fullname} -> %User{username: username, fullname: fullname} end)

      _ ->
        []
    end
  end

  def fetch_contributors(repo, try_count \\ 0)

  def fetch_contributors(_, try_count) when try_count > @retry_count do
    []
  end

  def fetch_contributors(repo, try_count) do
    (@base_url <> "/repos/#{repo}/stats/contributors")
    |> HTTPoison.get(rest_headers())
    |> case do
      {:ok, %{status_code: 200, body: body}} ->
        map_contributors(body)

      _ ->
        :timer.sleep(retry_delay())
        fetch_contributors(repo, try_count + 1)
    end
  end

  defp map_contributors(body) do
    body
    |> Jason.decode()
    |> case do
      {:ok, contributors} when is_list(contributors) ->
        contributors
        |> Enum.map(fn
          %{"author" => %{"login" => username}} = contributor ->
            {total, recent_commit_count, relevancy} = Contributors.calculate_relevancy(contributor)

            %Contributor{
              username: username,
              relevancy: relevancy,
              recent_commit_count: recent_commit_count,
              total_commit_count: total
            }

          _ ->
            nil
        end)
        |> Enum.reject(&is_nil/1)

      _ ->
        []
    end
  end

  defp retry_delay, do: Application.get_env(:dispatch, __MODULE__)[:retry_delay]
  defp access_token, do: Application.get_env(:dispatch, __MODULE__)[:access_token]

  defp graphql_headers, do: [{"Authorization", "bearer #{access_token()}"}]
  defp rest_headers, do: [{"Authorization", "token #{access_token()}"}]
end
