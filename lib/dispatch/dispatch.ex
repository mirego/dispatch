defmodule Dispatch do
  @moduledoc """
  Main module, exposes a way to fetch random reviewers for a repo
  and a way to request reviewers to a repo.
  """

  alias Dispatch.Absences
  alias Dispatch.Repositories
  alias Dispatch.Settings
  alias Dispatch.Utils.Normalization

  defmodule BlacklistedUser do
    @enforce_keys [:username]
    @derive Jason.Encoder
    defstruct username: nil
  end

  defmodule Expert do
    @enforce_keys [:username]
    @derive Jason.Encoder
    defstruct username: nil, type: nil, metadata: nil
  end

  defmodule Learner do
    @enforce_keys [:username, :exposure]
    @derive Jason.Encoder
    defstruct username: nil, exposure: nil, metadata: nil
  end

  defmodule SelectedUser do
    @enforce_keys [:username, :type]
    @derive Jason.Encoder
    defstruct username: nil, type: nil, metadata: nil
  end

  @doc """
  Returns a list of usernames that should be request to review the pull request
  """
  def fetch_selected_users(repo, stacks, author_username, disable_learners \\ false) do
    excluded_usernames = [author_username | Enum.map(Settings.blacklisted_users(), & &1.username)]

    # 1. Refresh settings
    Settings.refresh()

    # 2. Build a pool of requestable users
    requestable_usernames =
      repo
      |> Repositories.requestable_users()
      |> remove_absents()
      |> Enum.map(& &1.username)
      |> Kernel.--(excluded_usernames)

    # 3. Select relevant contributors from it
    contributors = Repositories.contributors(repo, requestable_usernames)
    requestable_usernames = update_requestable_usernames(requestable_usernames, Enum.map(contributors, & &1.username))

    # 4. Update the pool and then select a random stack-skilled expert for each stack
    stack_experts = Settings.experts(requestable_usernames, stacks)
    requestable_usernames = update_requestable_usernames(requestable_usernames, Enum.map(contributors, & &1.username))

    # 5. Update the pool and then randomly add -learners as reviewers for each stack
    stack_learners = if disable_learners, do: [], else: Settings.learners(requestable_usernames, stacks)

    # 6. Map all selected users to SelectedUser struct
    Enum.map(contributors ++ stack_experts ++ stack_learners, &struct(SelectedUser, Map.from_struct(&1)))
  end

  @doc """
  Request reviews from the specified reviewers on the pull request
  """
  def request_reviewers(repo, pull_request_number, reviewers) do
    requested_reviewers = Enum.filter(reviewers, &(request_or_mention_reviewer?(&1) == :request))

    with :ok <- Repositories.request_reviewers(repo, pull_request_number, requested_reviewers),
         :ok <- Repositories.create_request_comment(repo, pull_request_number, reviewers) do
      :ok
    else
      _ ->
        :error
    end
  end

  @doc """
  Extracts stacks from a Webhook payload received from GitHub
  """
  def extract_from_params(%{"pull_request" => %{"body" => body}} = params) do
    default_stacks = Map.get(params, "stacks", "")

    ~r/#dispatch\/([\w.]+)/i
    |> Regex.scan(body, capture: :all_but_first)
    |> (fn
          [] -> String.split(default_stacks, ",")
          stacks -> List.flatten(stacks)
        end).()
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.reject(&(&1 === ""))
  end

  def extract_from_params(_), do: []

  def request_or_mention_reviewer?(%SelectedUser{type: type}) when type in ["contributor", "expert"], do: :request
  def request_or_mention_reviewer?(_), do: :mention

  defp update_requestable_usernames(requestable_usernames, reviewer_usernames) do
    Enum.filter(requestable_usernames, &(&1 not in reviewer_usernames))
  end

  defp remove_absents(requestable_users), do: remove_absents(Absences.absent_fullnames(), requestable_users)

  defp remove_absents([], requestable_users), do: requestable_users

  defp remove_absents(absent_fullnames, requestable_users) do
    Enum.filter(requestable_users, fn
      %{fullname: nil} -> true
      %{fullname: fullname} -> Normalization.normalize(fullname) not in absent_fullnames
    end)
  end
end
