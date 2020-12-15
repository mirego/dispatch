defmodule Dispatch.Settings do
  alias Dispatch.Reviewer

  def blocklisted_users, do: client().blocklisted_users()
  def reviewer_users(stack), do: client().reviewer_users(stack)
  def learner_users(stack), do: client().learner_users(stack)
  def refresh, do: client().refresh()

  def reviewers(requestable_usernames, stacks) do
    stacks
    |> Enum.reduce(%{requestable_usernames: requestable_usernames, reviewers: []}, fn stack, acc ->
      reviewer_usernames =
        stack
        |> reviewer_users()
        |> Enum.map(& &1.username)
        |> keep_requestable_reviewers(acc[:requestable_usernames])
        |> Enum.take_random(1)

      acc
      |> remove_from_requestable_users(reviewer_usernames)
      |> add_to_reviewers(reviewer_usernames, stack)
    end)
    |> Map.get(:reviewers)
  end

  def learners(requestable_usernames, stacks) do
    stacks
    |> Enum.reduce(%{requestable_usernames: requestable_usernames, learners: []}, fn stack, acc ->
      stack_users =
        stack
        |> learner_users()
        |> keep_requestable_learners(acc[:requestable_usernames])
        |> Enum.filter(&(&1.exposure >= :rand.uniform()))

      acc
      |> remove_from_requestable_users(Enum.map(stack_users, & &1.username))
      |> add_to_learners(stack_users, stack)
    end)
    |> Map.get(:learners)
  end

  defp remove_from_requestable_users(acc, stack_users) do
    update_in(acc, [:requestable_usernames], &(&1 -- stack_users))
  end

  defp add_to_reviewers(acc, users, stack) do
    users = Enum.map(users, &%Reviewer{username: &1, type: "reviewer", metadata: %{stack: stack}})

    update_in(acc, [:reviewers], &(&1 ++ users))
  end

  defp add_to_learners(acc, users, stack) do
    users = Enum.map(users, &%Reviewer{username: &1.username, type: "learner", metadata: %{stack: stack, exposure: &1.exposure}})

    update_in(acc, [:learners], &(&1 ++ users))
  end

  defp keep_requestable_reviewers(reviewer_usernames, requestable_usernames) do
    Kernel.--(reviewer_usernames, reviewer_usernames -- requestable_usernames)
  end

  defp keep_requestable_learners(learner_usernames, requestable_users) do
    Enum.filter(learner_usernames, &(&1.username in requestable_users))
  end

  defp client, do: Application.get_env(:dispatch, Dispatch)[:settings_client]
end
