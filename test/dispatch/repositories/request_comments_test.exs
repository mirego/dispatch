defmodule Dispatch.Repositories.RequestCommentsTest do
  use ExUnit.Case, async: false

  alias Dispatch.Repositories.RequestComments
  alias Dispatch.SelectedUser

  test "request_comment/1 return the correct message for every selected users" do
    selected_users = [
      %SelectedUser{username: "user-1", type: "stack", metadata: %{stack: "elixir"}},
      %SelectedUser{username: "user-2", type: "stack", metadata: %{stack: "graphql"}},
      %SelectedUser{username: "user-3", type: "stack", metadata: %{anything: "anything"}},
      %SelectedUser{username: "user-4", type: "contributor", metadata: %{recent_commit_count: 20, total_commit_count: 256}},
      %SelectedUser{username: "user-5", type: "contributor", metadata: %{anything: "anything"}},
      %SelectedUser{username: "user-6", type: "learner"},
      %SelectedUser{username: "user-7", type: "learner", metadata: %{stack: "elixir"}},
      %SelectedUser{username: "user-8", type: "learner", metadata: %{stack: "graphql"}}
    ]

    expected_message = """
    **🦀 Requesting reviewers for this pull request:**

    * @user-1 (reviewer for the `elixir` stack)
    * @user-2 (reviewer for the `graphql` stack)
    * @user-3 (stack)
    * @user-4 (contributor with `20` commits in the last 90 days and `256` commits overall)
    * @user-5 (contributor)

    **🦀 Mentionning users for this pull request:**

    * @user-6 (learner)
    * @user-7 (learner for the `elixir` stack)
    * @user-8 (learner for the `graphql` stack)
    """

    result = RequestComments.request_comment(selected_users)
    assert result == String.trim(expected_message)
  end

  test "request_comment/1 return the correct message without learners" do
    selected_users = [
      %SelectedUser{username: "user-1", type: "stack", metadata: %{stack: "elixir"}},
      %SelectedUser{username: "user-4", type: "contributor", metadata: %{recent_commit_count: 20, total_commit_count: 256}}
    ]

    expected_message = """
    **🦀 Requesting reviewers for this pull request:**

    * @user-1 (reviewer for the `elixir` stack)
    * @user-4 (contributor with `20` commits in the last 90 days and `256` commits overall)
    """

    result = RequestComments.request_comment(selected_users)
    assert result == String.trim(expected_message)
  end
end
