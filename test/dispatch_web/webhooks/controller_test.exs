defmodule DispatchWeb.Webhooks.ControllerTest do
  use DispatchWeb.ConnCase

  import Mox

  alias Dispatch.BlacklistedUser
  alias Dispatch.Expert
  alias Dispatch.Learner
  alias Dispatch.SelectedUser

  alias Dispatch.Repositories.Contributor
  alias Dispatch.Repositories.User

  @requestable_users [
    %User{username: "foo", fullname: "foo"},
    %User{username: "biz", fullname: "biz"},
    %User{username: "bar", fullname: "bar"},
    %User{username: "pif", fullname: "pif"},
    %User{username: "paf", fullname: "paf"},
    %User{username: "ruby-master", fullname: "The Ruby Master"},
    %User{username: "ruby-learner", fullname: "The Ruby Learner"}
  ]
  @contributors [
    %Contributor{username: "bar", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "baz", relevancy: 0, recent_commit_count: 1, total_commit_count: 1},
    %Contributor{username: "omg", relevancy: 0, recent_commit_count: 1, total_commit_count: 1}
  ]

  setup :verify_on_exit!

  test "POST /webhooks with WIP pull request", %{conn: conn} do
    params = %{"stacks" => "elixir,graphql", "action" => "opened", "pull_request" => %{"title" => "WIP Add new feature"}}
    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{"success" => true, "noop" => true}
  end

  test "POST /webhooks with WIP: pull request", %{conn: conn} do
    params = %{"stacks" => "elixir,graphql", "action" => "opened", "pull_request" => %{"title" => "WIP:LOL"}}
    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{"success" => true, "noop" => true}
  end

  test "POST /webhooks with [WIP] pull request", %{conn: conn} do
    params = %{"stacks" => "elixir,graphql", "action" => "opened", "pull_request" => %{"title" => "[WIP] Add new feature"}}
    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{"success" => true, "noop" => true}
  end

  test "POST /webhooks with pull request from other organization", %{conn: conn} do
    params = %{"stacks" => "elixir,graphql", "action" => "opened", "pull_request" => %{"title" => "Add new feature", "repo" => %{"login" => "ixmedia"}}}
    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{"success" => true, "noop" => true}
  end

  test "POST /webhooks with invalid params", %{conn: conn} do
    params = %{"stacks" => "elixir,graphql", "action" => "closed"}
    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{"success" => true, "noop" => true}
  end

  test "POST /webhooks with disable_learners flag to true", %{conn: conn} do
    params = %{
      "disable_learners" => "true",
      "stacks" => "elixir",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
    |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)
    |> expect(:create_request_comment, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blacklisted_users, fn -> [] end)
    |> expect(:expert_users, fn "elixir" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{
             "success" => true,
             "noop" => false,
             "reviewers" => [
               %{
                 "metadata" => %{
                   "recent_commit_count" => 1,
                   "total_commit_count" => 1
                 },
                 "type" => "contributor",
                 "username" => "bar"
               }
             ]
           }
  end

  test "POST /webhooks without stacks", %{conn: conn} do
    params = %{
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
    |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)
    |> expect(:create_request_comment, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blacklisted_users, fn -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{
             "success" => true,
             "noop" => false,
             "reviewers" => [
               %{
                 "metadata" => %{
                   "recent_commit_count" => 1,
                   "total_commit_count" => 1
                 },
                 "type" => "contributor",
                 "username" => "bar"
               }
             ]
           }
  end

  test "POST /webhooks with stacks", %{conn: conn} do
    params = %{
      "stacks" => "elixir,graphql",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
    |> expect(:request_reviewers, fn "mirego/foo",
                                     1,
                                     [
                                       %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 1, total_commit_count: 1}},
                                       %SelectedUser{username: "biz", type: "stack", metadata: %{stack: "graphql"}}
                                     ] ->
      :ok
    end)
    |> expect(:create_request_comment, fn "mirego/foo",
                                          1,
                                          [
                                            %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 1, total_commit_count: 1}},
                                            %SelectedUser{username: "biz", type: "stack", metadata: %{stack: "graphql"}},
                                            %SelectedUser{username: "pif", type: "learner", metadata: %{stack: "elixir"}}
                                          ] ->
      :ok
    end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blacklisted_users, fn -> [%BlacklistedUser{username: "foo"}] end)
    |> expect(:expert_users, fn "elixir" -> [%Expert{username: "foo"}] end)
    |> expect(:expert_users, fn "graphql" -> [%Expert{username: "biz"}, %Expert{username: "omg"}] end)
    |> expect(:learner_users, fn "elixir" -> [%Learner{username: "paf", exposure: 0}, %Learner{username: "pif", exposure: 1}] end)
    |> expect(:learner_users, fn "graphql" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{
             "success" => true,
             "noop" => false,
             "reviewers" => [
               %{
                 "metadata" => %{
                   "recent_commit_count" => 1,
                   "total_commit_count" => 1
                 },
                 "type" => "contributor",
                 "username" => "bar"
               },
               %{
                 "metadata" => %{"stack" => "graphql"},
                 "type" => "stack",
                 "username" => "biz"
               },
               %{
                 "metadata" => %{"stack" => "elixir", "exposure" => 1},
                 "type" => "learner",
                 "username" => "pif"
               }
             ]
           }
  end

  test "POST /webhooks with stacks but overriden in pull request body", %{conn: conn} do
    params = %{
      "stacks" => "elixir,graphql",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo!\n\n#dispatch/ruby"}
    }

    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
    |> expect(:request_reviewers, fn "mirego/foo",
                                     1,
                                     [
                                       %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 1, total_commit_count: 1}},
                                       %SelectedUser{username: "ruby-master", type: "stack", metadata: %{stack: "ruby"}}
                                     ] ->
      :ok
    end)
    |> expect(:create_request_comment, fn "mirego/foo",
                                          1,
                                          [
                                            %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 1, total_commit_count: 1}},
                                            %SelectedUser{username: "ruby-master", type: "stack", metadata: %{stack: "ruby"}},
                                            %SelectedUser{username: "ruby-learner", type: "learner", metadata: %{stack: "ruby"}}
                                          ] ->
      :ok
    end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blacklisted_users, fn -> [%BlacklistedUser{username: "foo"}] end)
    |> expect(:expert_users, fn "ruby" -> [%Expert{username: "ruby-master"}] end)
    |> expect(:learner_users, fn "ruby" -> [%Learner{username: "ruby-learner", exposure: 1}] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{
             "success" => true,
             "noop" => false,
             "reviewers" => [
               %{
                 "metadata" => %{"recent_commit_count" => 1, "total_commit_count" => 1},
                 "type" => "contributor",
                 "username" => "bar"
               },
               %{
                 "metadata" => %{"stack" => "ruby"},
                 "type" => "stack",
                 "username" => "ruby-master"
               },
               %{
                 "metadata" => %{"stack" => "ruby", "exposure" => 1},
                 "type" => "learner",
                 "username" => "ruby-learner"
               }
             ]
           }
  end

  test "POST /webhooks with stacks but request return error", %{conn: conn} do
    params = %{
      "stacks" => "elixir,graphql",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
    |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :error end)
    |> expect(:create_request_comment, 0, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :error end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blacklisted_users, fn -> [] end)
    |> expect(:expert_users, fn "elixir" -> [] end)
    |> expect(:expert_users, fn "graphql" -> [] end)
    |> expect(:learner_users, fn "elixir" -> [] end)
    |> expect(:learner_users, fn "graphql" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    conn = post(conn, "/webhooks", params)
    assert json_response(conn, 200) == %{"success" => false, "noop" => false}
  end
end
