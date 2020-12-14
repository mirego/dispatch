defmodule Dispatch do
  @moduledoc """
  Main module, exposes a way to fetch random reviewers for a repo
  and a way to request reviewers to a repo.
  """

  alias Dispatch.AbsenceIO
  alias Dispatch.Blocklist
  alias Dispatch.RelevancyBooster
  alias Dispatch.Repositories
  alias Dispatch.Settings

  defmodule BlocklistedUser do
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

  # REFERENCE FOR DEV & EXPLANATION
  # (will be removed)
  #
  #  # Boosters (subject to change)
  #
  #  What is a booster? A booster is a "plugin" which can be used of not in the reviewers
  #  selection for a PR. Actually, it is pretty hard to step to the reviewers filtering system
  #  since everything is hardcoded.
  #
  #  With boosters, we could add them in a "organization" configuration.
  #
  #  For example, Mirego uses AbsenceIO, but another organization might be using a different service. Our
  #  current implementation make it hard to replace it. Using a list of boosters would make it easier.
  #
  #     *Boosters could be added in a release configuration file instead of hardcoded in this one.
  #
  # requestable_usernames =
  #   repo
  #   |> Repositories.requestable_users()
  #   |> RelevancyBooster.map_users()
  #   |> RelevancyBooster.calculate([
  #     {AbsenceIO.RelevancyBooster, []},
  #     {Blocklist.RelevancyBooster, author_username: author_username}
  #   ])
  #   |> map_selectable_users()
  #
  #  # Available boosters:
  #
  #  ## Boosters for blocklist & absents
  #
  #   - [x] AbsenceIOBooster
  #   - [x] BlocklistedBooster (global)
  #   - [ ] ProjectBlocklistedBooster (per project, gbourasse can say NO to Sobey’s since a full team of 6 devs is already in place for several months)
  #
  #  ## Boosters for contributors
  #
  #   Each booster leave a score trail so we can know WHY a user has been requested for review
  #
  #   - [ ] OneMonthCommitsBooster
  #   - [ ] ThreeMonthCommitsBooster
  #   - [ ] TwelveMonthCommitsBooster
  #   - ...
  #
  #  # How we select a contributor?
  #
  #  We calculate the sum of all score and factor it to 100. This percentage will be the chance
  #  the user has to get asked as a contributor reviewer.
  #
  #  [
  #    %UserRelevancy{
  #      username: "garno",
  #      fullname: "Samuel Garneau",
  #      type: "contributor",
  #      boosters: [
  #        {:one_month_commits, 100},
  #        {:three_months_commits, 40},
  #        {:twelve_months_commits, 30}
  #      ],
  #      score: 170
  #    },
  #    %UserRelevancy{
  #      username: "stevematte",
  #      fullname: "Steve Matte",
  #      type: "contributor",
  #      boosters: [
  #        {:one_month_commits, 130},
  #        {:three_months_commits, 50},
  #        {:twelve_months_commits, 40}
  #      ],
  #      score: 200
  #    }
  #  ]
  #
  #  Results:
  #
  #    - Sam has 45% chance of being requested as a contributor (170/(170+200)*100)
  #    - Sam has 55% chance of being requested as a contributor (200/(170+200)*100)
  #
  #  This way, old contributors have less chance of being requested with time and active
  #  contributors will get requested on their project more often.
  #
  #  We will need to tweak to "algo" once we will get some data. One of the step of this
  #  refactor will be to add an "optional" database (if possible) to keep track of the
  #  assigned reviews.
  #
  #  +------------------+
  #  | reviews          |
  #  +------------------+
  #  | + username       |
  #  | + repo           |
  #  | + pr             |
  #  | + relevancy      | <-- the boosters array with the score for each one
  #  | + score          |
  #  +------------------+
  #

  @doc """
  Returns a list of usernames that should be request to review the pull request
  """
  def fetch_selected_users(repo, stacks, author_username, disable_learners \\ false) do
    # 1. Refresh settings
    Settings.refresh()

    # 2. Build a pool of requestable users
    requestable_usernames =
      repo
      |> Repositories.requestable_users()
      |> RelevancyBooster.map_users()
      |> RelevancyBooster.calculate([
        {AbsenceIO.RelevancyBooster, []},
        {Blocklist.RelevancyBooster, author_username: author_username}
      ])
      |> map_selectable_users()

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

  defp map_selectable_users(user_relevancies) do
    user_relevancies
    |> Enum.filter(&(&1.score > 0))
    |> Enum.map(& &1.username)
  end

  defp update_requestable_usernames(requestable_usernames, reviewer_usernames) do
    Enum.filter(requestable_usernames, &(&1 not in reviewer_usernames))
  end
end
