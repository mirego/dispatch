defmodule Dispatch.RepositoriesTest do
  use ExUnit.Case

  import Mox

  alias Dispatch.Repositories
  alias Dispatch.Repositories.User

  @repository "mirego/foo"
  @requestable_users [
    %User{username: "foo", fullname: "foo"},
    %User{username: "fiz", fullname: "felix le chat"},
    %User{username: "biz", fullname: "biz"},
    %User{username: "bar", fullname: "bar"}
  ]

  setup :verify_on_exit!

  test "requestable_usernames/1 return users that has access to the repository" do
    expect(Dispatch.Repositories.MockClient, :fetch_requestable_users, fn @repository -> @requestable_users end)

    result = Repositories.requestable_users(@repository)

    assert Enum.map(result, & &1.username) == ["foo", "fiz", "biz", "bar"]
  end
end
