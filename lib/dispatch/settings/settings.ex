defmodule Dispatch.Settings do
  alias Dispatch.Expert

  def blocklisted_users, do: client().blocklisted_users()
  def expert_users(stack), do: client().expert_users(stack)
  def learner_users(stack), do: client().learner_users(stack)
  def refresh, do: client().refresh()

  def experts(requestable_usernames, stacks) do
    stacks
    |> Enum.reduce(%{requestable_usernames: requestable_usernames, experts: []}, fn stack, acc ->
      expert_usernames =
        stack
        |> expert_users()
        |> Enum.map(& &1.username)
        |> keep_requestable_experts(acc[:requestable_usernames])
        |> Enum.take_random(1)

      acc
      |> remove_from_requestable_users(expert_usernames)
      |> add_to_experts(expert_usernames, stack)
    end)
    |> Map.get(:experts)
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

  defp add_to_experts(acc, users, stack) do
    users = Enum.map(users, &%Expert{username: &1, type: "expert", metadata: %{stack: stack}})

    update_in(acc, [:experts], &(&1 ++ users))
  end

  defp add_to_learners(acc, users, stack) do
    users = Enum.map(users, &%Expert{username: &1.username, type: "learner", metadata: %{stack: stack, exposure: &1.exposure}})

    update_in(acc, [:learners], &(&1 ++ users))
  end

  defp keep_requestable_experts(expert_usernames, requestable_usernames) do
    Kernel.--(expert_usernames, expert_usernames -- requestable_usernames)
  end

  defp keep_requestable_learners(learner_usernames, requestable_users) do
    Enum.filter(learner_usernames, &(&1.username in requestable_users))
  end

  defp client, do: Application.get_env(:dispatch, Dispatch)[:settings_client]
end
