defmodule DispatchTest do
  use ExUnit.Case

  import Mox

  alias Dispatch.BlocklistedUser
  alias Dispatch.Expert
  alias Dispatch.Learner
  alias Dispatch.SelectedUser

  alias Dispatch.Repositories.Contributor
  alias Dispatch.Repositories.User
  alias Timex.Duration

  @requestable_users [%User{username: "foo", fullname: "foo"}, %User{username: "biz", fullname: "Biz"}, %User{username: "bar", fullname: "bar"}]

  setup :verify_on_exit!

  test "with blocklisted, random expert and random stack user" do
    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" ->
      [
        %Contributor{username: "bar", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "baz", relevancy: 0, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "omg", relevancy: 0, recent_commit_count: 1, total_commit_count: 1}
      ]
    end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [%BlocklistedUser{username: "foo"}] end)
    |> expect(:expert_users, fn "elixir" -> [%Expert{username: "foo"}] end)
    |> expect(:expert_users, fn "graphql" -> [%Expert{username: "biz"}, %Expert{username: "foo"}] end)
    |> expect(:learner_users, fn "elixir" -> [] end)
    |> expect(:learner_users, fn "graphql" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    selected_users = Dispatch.fetch_selected_users("mirego/foo", ["elixir", "graphql"], "omg")

    assert selected_users == [
             %SelectedUser{
               metadata: %{recent_commit_count: 1, total_commit_count: 1},
               type: "contributor",
               username: "bar"
             },
             %SelectedUser{
               metadata: %{stack: "graphql"},
               type: "expert",
               username: "biz"
             }
           ]
  end

  test "with blocklisted, random reviewer and random stack user in contributors" do
    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" ->
      [
        %Contributor{username: "bar", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "baz", relevancy: 0, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "omg", relevancy: 0, recent_commit_count: 1, total_commit_count: 1}
      ]
    end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [%BlocklistedUser{username: "foo"}] end)
    |> expect(:expert_users, fn "elixir" -> [%Expert{username: "foo"}] end)
    |> expect(:expert_users, fn "graphql" -> [%Expert{username: "bar"}, %Expert{username: "foo"}] end)
    |> expect(:learner_users, fn "elixir" -> [] end)
    |> expect(:learner_users, fn "graphql" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    selected_users = Dispatch.fetch_selected_users("mirego/foo", ["elixir", "graphql"], "omg")

    assert selected_users == [
             %SelectedUser{
               metadata: %{recent_commit_count: 1, total_commit_count: 1},
               type: "contributor",
               username: "bar"
             }
           ]
  end

  test "with blocklisted and absent, random reviewer and random stack user" do
    now = Timex.now()

    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" ->
      [
        %Contributor{username: "bar", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "baz", relevancy: 0, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "omg", relevancy: 0, recent_commit_count: 1, total_commit_count: 1}
      ]
    end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [%BlocklistedUser{username: "foo"}] end)
    |> expect(:expert_users, fn "elixir" -> [%Expert{username: "foo"}] end)
    |> expect(:expert_users, fn "graphql" -> [%Expert{username: "biz"}, %Expert{username: "omg"}] end)
    |> expect(:learner_users, fn "elixir" -> [] end)
    |> expect(:learner_users, fn "graphql" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn ->
      [
        %ExIcal.Event{
          start: Timex.subtract(now, Duration.from_minutes(60)),
          end: Timex.add(now, Duration.from_minutes(60)),
          summary: " Out of Office - Biz"
        }
      ]
    end)

    selected_users = Dispatch.fetch_selected_users("mirego/foo", ["elixir", "graphql"], "omg")

    assert selected_users == [
             %SelectedUser{
               metadata: %{recent_commit_count: 1, total_commit_count: 1},
               type: "contributor",
               username: "bar"
             }
           ]
  end

  test "with blocklisted, random reviewer and no stacks" do
    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" ->
      [
        %Contributor{username: "bar", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "baz", relevancy: 0, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "omg", relevancy: 0, recent_commit_count: 1, total_commit_count: 1}
      ]
    end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [%BlocklistedUser{username: "foo"}] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    selected_users = Dispatch.fetch_selected_users("mirego/foo", [], "omg")

    assert selected_users == [
             %SelectedUser{
               metadata: %{recent_commit_count: 1, total_commit_count: 1},
               type: "contributor",
               username: "bar"
             }
           ]
  end

  test "without blocklisted or stack users" do
    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" ->
      [
        %Contributor{username: "bar", relevancy: 1, recent_commit_count: 1, total_commit_count: 1},
        %Contributor{username: "baz", relevancy: 0, recent_commit_count: 1, total_commit_count: 1}
      ]
    end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [] end)
    |> expect(:expert_users, fn "elixir" -> [] end)
    |> expect(:learner_users, fn "elixir" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    selected_users = Dispatch.fetch_selected_users("mirego/foo", ["elixir"], "omg")

    assert selected_users == [
             %SelectedUser{
               metadata: %{recent_commit_count: 1, total_commit_count: 1},
               type: "contributor",
               username: "bar"
             }
           ]
  end

  test "without contributor" do
    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> [] end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [] end)
    |> expect(:expert_users, fn "elixir" -> [] end)
    |> expect(:learner_users, fn "elixir" -> [] end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    selected_users = Dispatch.fetch_selected_users("mirego/foo", ["elixir"], "omg")

    assert selected_users == []
  end

  test "with blocklisted, 2 out of 3 requestable learners selected via exposure" do
    Dispatch.Repositories.MockClient
    |> expect(:fetch_requestable_users, fn "mirego/foo" -> @requestable_users end)
    |> expect(:fetch_contributors, fn "mirego/foo" -> [] end)

    Dispatch.Settings.MockClient
    |> expect(:refresh, fn -> true end)
    |> expect(:blocklisted_users, fn -> [] end)
    |> expect(:expert_users, fn "elixir" -> [] end)
    |> expect(:learner_users, fn "elixir" ->
      [
        %Learner{username: "foo", exposure: 1},
        %Learner{username: "biz", exposure: 0},
        %Learner{username: "bar", exposure: 1},
        %Learner{username: "buzz", exposure: 1}
      ]
    end)

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    selected_users = Dispatch.fetch_selected_users("mirego/foo", ["elixir"], "omg")

    assert selected_users == [
             %SelectedUser{
               metadata: %{stack: "elixir", exposure: 1},
               type: "learner",
               username: "foo"
             },
             %SelectedUser{
               metadata: %{stack: "elixir", exposure: 1},
               type: "learner",
               username: "bar"
             }
           ]
  end

  test "extract_from_params/1 without stacks in pull request body, it should return the default stacks" do
    stacks = Dispatch.extract_from_params(%{"pull_request" => %{"body" => ""}, "stacks" => "foo,Bar"})

    assert stacks == ["foo", "bar"]
  end

  test "extract_from_params/1 without stacks in pull request body nor in params" do
    stacks = Dispatch.extract_from_params(%{"pull_request" => %{"body" => ""}})

    assert stacks == []
  end

  test "extract_from_params/1 with stacks in pull request body, it should return them" do
    body = """
    This is my pull request! It adds a Terraform configuration file. Absolutely no GraphQL stuff to review.

    #dispatch/hcl #dispatch/Ruby
    """

    stacks = Dispatch.extract_from_params(%{"pull_request" => %{"body" => body}, "stacks" => "ruby,graphql"})

    assert stacks == ["hcl", "ruby"]
  end

  test "extract_from_params/1 with stacks in pull request body but no default ones, it should return them" do
    body = """
    This is my pull request! It adds a Terraform configuration file. Absolutely no GraphQL stuff to review.

    Also, there are no default stacks in the webhook URL.

    #dispatch/hcl #dispatch/Ruby #dispatch/node.js
    """

    stacks = Dispatch.extract_from_params(%{"pull_request" => %{"body" => body}})

    assert stacks == ["hcl", "ruby", "node.js"]
  end
end
