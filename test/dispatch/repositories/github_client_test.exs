defmodule Dispatch.Repositories.GitHubClientTest do
  use ExUnit.Case, async: false

  import Mock

  alias Dispatch.Repositories.Contributor
  alias Dispatch.Repositories.GitHubClient
  alias Dispatch.Repositories.User
  alias Dispatch.SelectedUser
  alias Dispatch.Utils.TimeHelper

  @this_week 1
  @two_month_ago 60
  @five_month_ago 150

  test "fetch_contributors/1" do
    contributors = """
    [
      {
        "total": 125,
        "weeks": [
          {
            "w": #{TimeHelper.unix_beginning_of_week(@five_month_ago)},
            "a": 0,
            "d": 0,
            "c": 11
          },
          {
            "w": #{TimeHelper.unix_beginning_of_week(@two_month_ago)},
            "a": 0,
            "d": 0,
            "c": 2
          },
          {
            "w": #{TimeHelper.unix_beginning_of_week(@this_week)},
            "a": 0,
            "d": 0,
            "c": 2
          }
        ],
        "author": {
          "login": "low-key"
        }
      },
      {
        "total": 100,
        "weeks": [
          {
            "w": #{TimeHelper.unix_beginning_of_week(@five_month_ago)},
            "a": 0,
            "d": 0,
            "c": 25
          },
          {
            "w": #{TimeHelper.unix_beginning_of_week(@two_month_ago)},
            "a": 0,
            "d": 0,
            "c": 1
          }
        ],
        "author": {
          "login": "calcula_thor"
        }
      },
      {
        "total": 12,
        "weeks": [
          {
            "w": #{TimeHelper.unix_beginning_of_week(@five_month_ago)},
            "a": 0,
            "d": 0,
            "c": 12
          }
        ],
        "author": {
          "login": "hulkhogan"
        }
      }
    ]
    """

    with_mock HTTPoison, get: fn "https://api.github.com/repos/mirego/foo/stats/contributors", _ -> {:ok, %{status_code: 200, body: contributors}} end do
      result = GitHubClient.fetch_contributors("mirego/foo")

      assert result == [
               %Contributor{username: "low-key", relevancy: 129, recent_commit_count: 4, total_commit_count: 125},
               %Contributor{username: "calcula_thor", relevancy: 101, recent_commit_count: 1, total_commit_count: 100},
               %Contributor{username: "hulkhogan", relevancy: 12, recent_commit_count: 0, total_commit_count: 12}
             ]
    end
  end

  test "fetch_contributors/1 ignore unparsable contributor" do
    contributors = """
    [
      {
        "total": 125,
        "weeks": [
          {
          "w": #{TimeHelper.unix_beginning_of_week(@five_month_ago)},
          "a": 0,
          "d": 0,
          "c": 11
          },
          {
          "w": #{TimeHelper.unix_beginning_of_week(@two_month_ago)},
          "a": 0,
          "d": 0,
          "c": 2
          },
          {
          "w": #{TimeHelper.unix_beginning_of_week(@this_week)},
          "a": 0,
          "d": 0,
          "c": 2
          }
        ],
        "author": {
          "login": "low-key"
        }
      },
      {
        "total": 4,
        "weeks": [],
        "author": "unparsable"
      }
    ]
    """

    with_mock HTTPoison, get: fn "https://api.github.com/repos/mirego/foo/stats/contributors", _ -> {:ok, %{status_code: 200, body: contributors}} end do
      result = GitHubClient.fetch_contributors("mirego/foo")

      assert result == [
               %Contributor{username: "low-key", relevancy: 129, recent_commit_count: 4, total_commit_count: 125}
             ]
    end
  end

  test "fetch_contributors/1 return empty list when body is not a contributor list" do
    error = "{\"documentation_url\": \"https://developer.github.com/v3/repos/statistics/#get-contributors-list-with-additions-deletions-and-commit-counts\"}"

    with_mock HTTPoison, get: fn "https://api.github.com/repos/mirego/foo/stats/contributors", _ -> {:ok, %{status_code: 200, body: error}} end do
      result = GitHubClient.fetch_contributors("mirego/foo")

      assert result == []
    end
  end

  test "fetch_contributors/1 return empty list on error" do
    with_mock HTTPoison, get: fn "https://api.github.com/repos/mirego/foo/stats/contributors", _ -> {:error, "The roof is on fire"} end do
      result = GitHubClient.fetch_contributors("mirego/foo")

      assert result == []
    end
  end

  test "fetch_contributors/1 return empty list on invalid body" do
    with_mock HTTPoison, get: fn "https://api.github.com/repos/mirego/foo/stats/contributors", _ -> {:ok, %{status_code: 200, body: "This isn't json"}} end do
      result = GitHubClient.fetch_contributors("mirego/foo")

      assert result == []
    end
  end

  test "fetch_contributors/1 return empty list if fail 10 times" do
    with_mock HTTPoison, get: fn "https://api.github.com/repos/mirego/foo/stats/contributors", _ -> {:ok, %{status_code: 202}} end do
      result = GitHubClient.fetch_contributors("mirego/foo")

      assert result == []
    end
  end

  test "fetch_requestable_users/1" do
    body = """
      {
        "data": {
          "repository": {
            "assignableUsers": {
              "nodes": [
                {
                  "login": "spider-man",
                  "name": "Peter Parker"
                },
                {
                  "login": "hulk",
                  "name": "Bruce Banner"
                }
              ]
            }
          }
        }
      }
    """

    with_mock HTTPoison, post: fn "https://api.github.com/graphql", _, _ -> {:ok, %{status_code: 200, body: body}} end do
      result = GitHubClient.fetch_requestable_users("mirego/foo")

      assert result == [%User{username: "spider-man", fullname: "Peter Parker"}, %User{username: "hulk", fullname: "Bruce Banner"}]
    end
  end

  test "fetch_requestable_users/1 return empty list if fail 10 times" do
    with_mock HTTPoison, post: fn "https://api.github.com/graphql", _, _ -> {:error, "error"} end do
      result = GitHubClient.fetch_requestable_users("mirego/foo")

      assert result == []
    end
  end

  test "fetch_requestable_users/1 return empty list on invalid body" do
    with_mock HTTPoison, post: fn "https://api.github.com/graphql", _, _ -> {:ok, %{status_code: 200, body: "This isn't json"}} end do
      result = GitHubClient.fetch_requestable_users("mirego/foo")

      assert result == []
    end
  end

  test "request_reviewers/3 without reviewers" do
    assert :ok == GitHubClient.request_reviewers("mirego/foo", 123, [])
  end

  test "request_reviewers/3 with successful response" do
    expected_url = "https://api.github.com/repos/mirego/foo/pulls/123/requested_reviewers"
    body = "{\"reviewers\":[\"morpheus\",\"neo\"]}"

    with_mock HTTPoison, post: fn ^expected_url, ^body, _ -> {:ok, %HTTPoison.Response{status_code: 201}} end do
      assert :ok ==
               GitHubClient.request_reviewers("mirego/foo", 123, [%SelectedUser{username: "morpheus", type: "contributor"}, %SelectedUser{username: "neo", type: "stack/assembler"}])
    end
  end

  test "request_reviewers/3 with non-successful response" do
    expected_url = "https://api.github.com/repos/mirego/foo/pulls/123/requested_reviewers"
    body = "{\"reviewers\":[\"morpheus\",\"neo\"]}"

    with_mock HTTPoison, post: fn ^expected_url, ^body, _ -> {:ok, %HTTPoison.Response{status_code: 404}} end do
      assert :error ==
               GitHubClient.request_reviewers("mirego/foo", 123, [%SelectedUser{username: "morpheus", type: "contributor"}, %SelectedUser{username: "neo", type: "stack/assembler"}])
    end
  end

  test "request_reviewers/3 with erroneous response" do
    expected_url = "https://api.github.com/repos/mirego/foo/pulls/123/requested_reviewers"
    body = "{\"reviewers\":[\"morpheus\",\"neo\"]}"

    with_mock HTTPoison, post: fn ^expected_url, ^body, _ -> {:error, "error"} end do
      assert :error ==
               GitHubClient.request_reviewers("mirego/foo", 123, [%SelectedUser{username: "morpheus", type: "contributor"}, %SelectedUser{username: "neo", type: "stack/assembler"}])
    end
  end

  test "create_request_comment/3 without reviewers" do
    assert :ok == GitHubClient.create_request_comment("mirego/foo", 123, [])
  end

  test "create_request_comment/3 with successful response" do
    expected_url = "https://api.github.com/repos/mirego/foo/issues/123/comments"
    body = "{\"body\":\"**🦀 Requesting reviewers for this pull request:**\\n\\n* @morpheus (contributor)\\n* @neo (stack)\"}"

    with_mock HTTPoison, post: fn ^expected_url, ^body, _ -> {:ok, %HTTPoison.Response{status_code: 201}} end do
      assert :ok ==
               GitHubClient.create_request_comment("mirego/foo", 123, [%SelectedUser{username: "morpheus", type: "contributor"}, %SelectedUser{username: "neo", type: "stack"}])
    end
  end

  test "create_request_comment/3 with non-successful response" do
    expected_url = "https://api.github.com/repos/mirego/foo/issues/123/comments"
    body = "{\"body\":\"**🦀 Requesting reviewers for this pull request:**\\n\\n* @morpheus (contributor)\\n* @neo (stack)\"}"

    with_mock HTTPoison, post: fn ^expected_url, ^body, _ -> {:ok, %HTTPoison.Response{status_code: 404}} end do
      assert :error ==
               GitHubClient.create_request_comment("mirego/foo", 123, [%SelectedUser{username: "morpheus", type: "contributor"}, %SelectedUser{username: "neo", type: "stack"}])
    end
  end

  test "create_request_comment/3 with erroneous response" do
    expected_url = "https://api.github.com/repos/mirego/foo/issues/123/comments"
    body = "{\"body\":\"**🦀 Requesting reviewers for this pull request:**\\n\\n* @morpheus (contributor)\\n* @neo (stack)\"}"

    with_mock HTTPoison, post: fn ^expected_url, ^body, _ -> {:error, "error"} end do
      assert :error ==
               GitHubClient.create_request_comment("mirego/foo", 123, [%SelectedUser{username: "morpheus", type: "contributor"}, %SelectedUser{username: "neo", type: "stack"}])
    end
  end
end
