defmodule Dispatch.Settings.JSONStaticFileClientTest do
  use ExUnit.Case

  import Mock

  alias Dispatch.Settings.JSONStaticFileClient, as: Client

  test "empty learners" do
    body = """
    {
      "learners": {},
      "blocklist": {},
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
      "blocklist": [],
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
      "blocklist": [],
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

  test "blocklist" do
    body = """
    {
      "learners": {},
      "blocklist": [
        {
          "username": "test"
        }
      ],
      "experts": {}
    }
    """

    with_mock HTTPoison, get: fn _ -> {:ok, %HTTPoison.Response{status_code: 200, body: body}} end do
      Client.refresh()

      users = Client.blocklisted_users()
      assert users === [%Dispatch.BlocklistedUser{username: "test"}]
    end
  end

  test "deprecated blacklist" do
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

      users = Client.blocklisted_users()
      assert users === [%Dispatch.BlocklistedUser{username: "test"}]
    end
  end

  test "stacks" do
    body = """
    {
      "learners": {
        "elixir": [],
        "javascript": []
      },
      "blocklist": [],
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
      blocklisted = Client.blocklisted_users()
      experts = Client.expert_users("elixir")
      learners = Client.learner_users("elixir")

      assert length(learners) === 0
      assert length(experts) === 0
      assert length(blocklisted) === 0
      assert length(stacks) === 0
    end
  end
end
