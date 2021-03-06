defmodule Dispatch.Settings.JSONStaticFileClient do
  use Agent

  @behaviour Dispatch.Settings.ClientBehaviour

  alias Dispatch.{BlocklistedUser, Learner, Reviewer}
  alias Dispatch.Settings.ClientBehaviour

  defmodule State do
    @enforce_keys ~w(reviewers learners blocklist)a
    defstruct reviewers: nil, learners: nil, blocklist: nil
  end

  def start_link do
    state = build_state()

    Agent.start_link(fn -> state end, name: __MODULE__)
  end

  @impl ClientBehaviour
  def reviewer_users(stack) do
    __MODULE__
    |> Agent.get(& &1.reviewers)
    |> Map.get(stack, [])
    |> Enum.map(&%Reviewer{username: &1["username"]})
  end

  @impl ClientBehaviour
  def learner_users(stack) do
    __MODULE__
    |> Agent.get(& &1.learners)
    |> Map.get(stack, [])
    |> Enum.map(&%Learner{username: &1["username"], exposure: &1["exposure"]})
  end

  @impl ClientBehaviour
  def blocklisted_users do
    __MODULE__
    |> Agent.get(& &1.blocklist)
    |> Enum.map(&%BlocklistedUser{username: &1["username"]})
  end

  @impl ClientBehaviour
  def stacks do
    reviewers = Agent.get(__MODULE__, & &1.reviewers)
    learners = Agent.get(__MODULE__, & &1.learners)

    reviewers
    |> Map.merge(learners)
    |> Map.keys()
  end

  @impl ClientBehaviour
  def refresh do
    state = build_state()
    Agent.update(__MODULE__, fn _ -> state end)
  end

  defp build_state do
    {:ok, configuration} = fetch_configuration_file()

    %State{
      learners: Map.get(configuration, "learners", %{}),
      reviewers: Map.get(configuration, "reviewers", Map.get(configuration, "experts", %{})),
      blocklist: Map.get(configuration, "blocklist", Map.get(configuration, "blacklist", []))
    }
  end

  defp fetch_configuration_file do
    with path when is_binary(path) and path != "" <- configuration_file_url(),
         {:ok, %HTTPoison.Response{status_code: 200, body: body}} <- HTTPoison.get(path) do
      Jason.decode(body)
    else
      _ -> {:ok, %{}}
    end
  end

  defp configuration_file_url, do: Application.get_env(:dispatch, __MODULE__)[:configuration_file_url]
end
