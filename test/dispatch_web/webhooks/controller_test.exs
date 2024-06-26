defmodule DispatchWeb.Webhooks.ControllerTest do
  use DispatchWeb.ConnCase

  import Mox
  import Mock

  alias Dispatch.BlocklistedUser
  alias Dispatch.Learner
  alias Dispatch.Reviewer
  alias Dispatch.SelectedUser

  alias Dispatch.Repositories.Contributor
  alias Dispatch.Repositories.User

  alias Dispatch.Utils.Random

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
    %Contributor{username: "bar", relevancy: 2, recent_commit_count: 2, total_commit_count: 2},
    %Contributor{username: "biz", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
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

  test "POST /webhooks with a draft pull request", %{conn: conn} do
    params = %{"stacks" => "elixir,graphql", "action" => "opened", "pull_request" => %{"draft" => true}}
    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{"success" => true, "noop" => true}
  end

  test "POST /webhooks with pull request from bots", %{conn: conn} do
    params = %{"stacks" => "elixir,graphql", "action" => "opened", "pull_request" => %{"user" => %{"type" => "Bot"}}}
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

    with_mock Random,
      uniform: fn
        3 -> 1
      end do
      Dispatch.Repositories.MockClient
      |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
      |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
      |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)
      |> expect(:create_request_comment, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)

      Dispatch.Settings.MockClient
      |> expect(:refresh, fn -> true end)
      |> expect(:blocklisted_users, fn -> [] end)
      |> expect(:reviewer_users, fn "elixir" -> [] end)

      expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

      conn = post(conn, "/webhooks", params)

      assert json_response(conn, 200) == %{
               "success" => true,
               "noop" => false,
               "reviewers" => [
                 %{
                   "metadata" => %{
                     "recent_commit_count" => 2,
                     "total_commit_count" => 2
                   },
                   "type" => "contributor",
                   "username" => "bar"
                 }
               ]
             }
    end
  end

  test "POST /webhooks without stacks", %{conn: conn} do
    params = %{
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    with_mock Random,
      uniform: fn
        3 -> 1
      end do
      Dispatch.Repositories.MockClient
      |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
      |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
      |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)
      |> expect(:create_request_comment, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)

      Dispatch.Settings.MockClient
      |> expect(:refresh, fn -> true end)
      |> expect(:blocklisted_users, fn -> [] end)

      expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

      conn = post(conn, "/webhooks", params)

      assert json_response(conn, 200) == %{
               "success" => true,
               "noop" => false,
               "reviewers" => [
                 %{
                   "metadata" => %{
                     "recent_commit_count" => 2,
                     "total_commit_count" => 2
                   },
                   "type" => "contributor",
                   "username" => "bar"
                 }
               ]
             }
    end
  end

  test "POST /webhooks with stacks", %{conn: conn} do
    params = %{
      "stacks" => "elixir,graphql",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    with_mock Random,
      uniform: fn
        3 -> 1
      end do
      Dispatch.Repositories.MockClient
      |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
      |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
      |> expect(:request_reviewers, fn "mirego/foo",
                                       1,
                                       [
                                         %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 2, total_commit_count: 2}},
                                         %SelectedUser{username: "biz", type: "reviewer", metadata: %{stack: "graphql"}}
                                       ] ->
        :ok
      end)
      |> expect(:create_request_comment, fn "mirego/foo",
                                            1,
                                            [
                                              %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 2, total_commit_count: 2}},
                                              %SelectedUser{username: "biz", type: "reviewer", metadata: %{stack: "graphql"}},
                                              %SelectedUser{username: "pif", type: "learner", metadata: %{stack: "elixir"}}
                                            ] ->
        :ok
      end)

      Dispatch.Settings.MockClient
      |> expect(:refresh, fn -> true end)
      |> expect(:blocklisted_users, fn -> [%BlocklistedUser{username: "foo"}] end)
      |> expect(:reviewer_users, fn "elixir" -> [%Reviewer{username: "foo"}] end)
      |> expect(:reviewer_users, fn "graphql" -> [%Reviewer{username: "biz"}, %Reviewer{username: "omg"}] end)
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
                     "recent_commit_count" => 2,
                     "total_commit_count" => 2
                   },
                   "type" => "contributor",
                   "username" => "bar"
                 },
                 %{
                   "metadata" => %{"stack" => "graphql"},
                   "type" => "reviewer",
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
  end

  test "POST /webhooks with stacks but overriden in pull request body", %{conn: conn} do
    params = %{
      "stacks" => "elixir,graphql",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo!\n\n#dispatch/ruby"}
    }

    with_mock Random,
      uniform: fn
        3 -> 1
      end do
      Dispatch.Repositories.MockClient
      |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
      |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
      |> expect(:request_reviewers, fn "mirego/foo",
                                       1,
                                       [
                                         %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 2, total_commit_count: 2}},
                                         %SelectedUser{username: "ruby-master", type: "reviewer", metadata: %{stack: "ruby"}}
                                       ] ->
        :ok
      end)
      |> expect(:create_request_comment, fn "mirego/foo",
                                            1,
                                            [
                                              %SelectedUser{username: "bar", type: "contributor", metadata: %{recent_commit_count: 2, total_commit_count: 2}},
                                              %SelectedUser{username: "ruby-master", type: "reviewer", metadata: %{stack: "ruby"}},
                                              %SelectedUser{username: "ruby-learner", type: "learner", metadata: %{stack: "ruby"}}
                                            ] ->
        :ok
      end)

      Dispatch.Settings.MockClient
      |> expect(:refresh, fn -> true end)
      |> expect(:blocklisted_users, fn -> [%BlocklistedUser{username: "foo"}] end)
      |> expect(:reviewer_users, fn "ruby" -> [%Reviewer{username: "ruby-master"}] end)
      |> expect(:learner_users, fn "ruby" -> [%Learner{username: "ruby-learner", exposure: 1}] end)

      expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

      conn = post(conn, "/webhooks", params)

      assert json_response(conn, 200) == %{
               "success" => true,
               "noop" => false,
               "reviewers" => [
                 %{
                   "metadata" => %{"recent_commit_count" => 2, "total_commit_count" => 2},
                   "type" => "contributor",
                   "username" => "bar"
                 },
                 %{
                   "metadata" => %{"stack" => "ruby"},
                   "type" => "reviewer",
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
  end

  test "POST /webhooks with stacks but request return error", %{conn: conn} do
    params = %{
      "stacks" => "elixir,graphql",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    with_mock Random,
      uniform: fn
        3 -> 1
      end do
      Dispatch.Repositories.MockClient
      |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
      |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
      |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :error end)
      |> expect(:create_request_comment, 0, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :error end)

      Dispatch.Settings.MockClient
      |> expect(:refresh, fn -> true end)
      |> expect(:blocklisted_users, fn -> [] end)
      |> expect(:reviewer_users, fn "elixir" -> [] end)
      |> expect(:reviewer_users, fn "graphql" -> [] end)
      |> expect(:learner_users, fn "elixir" -> [] end)
      |> expect(:learner_users, fn "graphql" -> [] end)

      expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

      conn = post(conn, "/webhooks", params)
      assert json_response(conn, 200) == %{"success" => false, "noop" => false}
    end
  end

  test "POST /webhooks from a non-organization pull request", %{conn: conn} do
    params = %{
      "stacks" => "elixir,graphql",
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "non_mirego/foo", "owner" => %{"login" => "non_mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    conn = post(conn, "/webhooks", params)
    assert json_response(conn, 200) == %{"success" => true, "noop" => true}
  end

  test "POST /webhooks without selected reviewers", %{conn: conn} do
    params = %{
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> [] end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> [] end)
    |> expect(:request_reviewers, fn "mirego/foo", 1, [] -> :ok end)
    |> expect(:create_request_comment, fn "mirego/foo", 1, [] -> :ok end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    conn = post(conn, "/webhooks", params)

    assert json_response(conn, 200) == %{
             "success" => true,
             "noop" => false,
             "reviewers" => []
           }
  end

  test "POST /webhooks with a ready for review pull request", %{conn: conn} do
    params = %{
      "action" => "ready_for_review",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    with_mock Random,
      uniform: fn
        3 -> 1
      end do
      Dispatch.Repositories.MockClient
      |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
      |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
      |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)
      |> expect(:create_request_comment, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}] -> :ok end)

      Dispatch.Settings.MockClient
      |> expect(:refresh, fn -> true end)
      |> expect(:blocklisted_users, fn -> [] end)

      expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

      conn = post(conn, "/webhooks", params)

      assert json_response(conn, 200) == %{
               "success" => true,
               "noop" => false,
               "reviewers" => [
                 %{
                   "metadata" => %{
                     "recent_commit_count" => 2,
                     "total_commit_count" => 2
                   },
                   "type" => "contributor",
                   "username" => "bar"
                 }
               ]
             }
    end
  end

  test "POST /webhooks with minimum_contributor_count flag", %{conn: conn} do
    params = %{
      "minimum_contributor_count" => 2,
      "action" => "opened",
      "number" => 1,
      "repository" => %{"full_name" => "mirego/foo", "owner" => %{"login" => "mirego"}},
      "pull_request" => %{"user" => %{"login" => "remiprev"}, "body" => "Foo"}
    }

    with_mock Random,
      uniform: fn
        3 -> 1
        1 -> 1
      end do
      Dispatch.Repositories.MockClient
      |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
      |> expect(:fetch_contributors, fn "mirego/foo" -> @contributors end)
      |> expect(:request_reviewers, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}, %SelectedUser{username: "biz", type: "contributor"}] -> :ok end)
      |> expect(:create_request_comment, fn "mirego/foo", 1, [%SelectedUser{username: "bar", type: "contributor"}, %SelectedUser{username: "biz", type: "contributor"}] -> :ok end)

      Dispatch.Settings.MockClient
      |> expect(:refresh, fn -> true end)
      |> expect(:blocklisted_users, fn -> [] end)

      expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

      conn = post(conn, "/webhooks", params)

      assert json_response(conn, 200) == %{
               "success" => true,
               "noop" => false,
               "reviewers" => [
                 %{
                   "metadata" => %{
                     "recent_commit_count" => 2,
                     "total_commit_count" => 2
                   },
                   "type" => "contributor",
                   "username" => "bar"
                 },
                 %{
                   "metadata" => %{
                     "recent_commit_count" => 1,
                     "total_commit_count" => 1
                   },
                   "type" => "contributor",
                   "username" => "biz"
                 }
               ]
             }
    end
  end
end
