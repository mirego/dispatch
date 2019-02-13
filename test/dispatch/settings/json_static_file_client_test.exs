defmodule Dispatch.Settings.JSONStaticFileClientTest do
  use ExUnit.Case

  import Mock

  alias Dispatch.Settings.JSONStaticFileClient, as: Client

  test "empty learners" do
    body = """
    {
      "learners": {},
      "blacklist": {},
      "experts": {}
    }
    """

    with_mock HTTPoison, get: fn _ -> {:ok, %HTTPoison.Response{status_code: 200, body: body}} end do
      Client.refresh()

      users = Client.learner_users("elixir")
      assert users === []
    end
  end

  test "stack learners" do
    body = """
    {
      "learners": {
        "elixir": [
          {
            "username": "test",
            "exposure": 0.25
          }
        ]
      },
      "blacklist": [],
      "experts": {}
    }
    """

    with_mock HTTPoison, get: fn _ -> {:ok, %HTTPoison.Response{status_code: 200, body: body}} end do
      Client.refresh()

      users = Client.learner_users("elixir")
      assert users === [%Dispatch.Learner{username: "test", exposure: 0.25}]
    end
  end

  test "stack experts" do
    body = """
    {
      "learners": {},
      "blacklist": [],
      "experts": {
        "elixir": [
          {
            "username": "test"
          }
        ]
      }
    }
    """

    with_mock HTTPoison, get: fn _ -> {:ok, %HTTPoison.Response{status_code: 200, body: body}} end do
      Client.refresh()

      users = Client.expert_users("elixir")
      assert users === [%Dispatch.Expert{username: "test"}]
    end
  end

  test "blacklist" do
    body = """
    {
      "learners": {},
      "blacklist": [
        {
          "username": "test"
        }
      ],
      "experts": {}
    }
    """

    with_mock HTTPoison, get: fn _ -> {:ok, %HTTPoison.Response{status_code: 200, body: body}} end do
      Client.refresh()

      users = Client.blacklisted_users()
      assert users === [%Dispatch.BlacklistedUser{username: "test"}]
    end
  end

  test "stacks" do
    body = """
    {
      "learners": {
        "elixir": [],
        "javascript": []
      },
      "blacklist": [],
      "experts": {
        "javascript": [],
        "react": []
      }
    }
    """

    with_mock HTTPoison, get: fn _ -> {:ok, %HTTPoison.Response{status_code: 200, body: body}} end do
      Client.refresh()

      stacks = Client.stacks()
      assert length(stacks) === 3
      assert "elixir" in stacks
      assert "javascript" in stacks
      assert "react" in stacks
    end
  end

  test "http error" do
    with_mock HTTPoison, get: fn _ -> {:ok, %HTTPoison.Response{status_code: 401, body: "Unauthorized"}} end do
      Client.refresh()

      stacks = Client.stacks()
      blacklisted = Client.blacklisted_users()
      experts = Client.expert_users("elixir")
      learners = Client.learner_users("elixir")

      assert length(learners) === 0
      assert length(experts) === 0
      assert length(blacklisted) === 0
      assert length(stacks) === 0
    end
  end
end
