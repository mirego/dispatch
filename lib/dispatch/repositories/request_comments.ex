defmodule Dispatch.Repositories.RequestComments do
  @request_comment_template """
  **🦀 Requesting reviewers for this pull request:**

  <%= for line <- requested_reviewer_lines do %><%= line %><% end %>
  <%= if length(mentioned_reviewer_lines) > 0 do %>**🦀 Mentionning users for this pull request:**

  <%= for line <- mentioned_reviewer_lines do %><%= line %><% end %>
  <% end %>
  """

  @doc """
  Create a formatted message listing why the reviewers were chosen

  Example:
  Given a list of 3 reviewers

  %{username: "John", type: "contributor", metadata: %{relevancy: "23/99"}}
  %{username: "Jane", type: "stack", metadata: %{stack: "elixir"}}
  %{username: "Joe", type: "stack", metadata: %{stack: "graphql"}}
  %{username: "Jerry", type: "learner"}

  So reviewers will be displayed like this:

  @John (contributor with 23% relevancy)
  @Jane (reviewer for the elixir stack)
  @Joe (reviewer for the graphql stack)
  @Jerry (learner)
  """
  def request_comment(reviewers) do
    requested_reviewer_lines =
      reviewers
      |> Enum.filter(&(Dispatch.request_or_mention_reviewer?(&1) == :request))
      |> Enum.map(&reviewer_line/1)

    mentioned_reviewer_lines =
      reviewers
      |> Enum.filter(&(Dispatch.request_or_mention_reviewer?(&1) == :mention))
      |> Enum.map(&reviewer_line/1)

    @request_comment_template
    |> EEx.eval_string(requested_reviewer_lines: requested_reviewer_lines, mentioned_reviewer_lines: mentioned_reviewer_lines)
    |> String.trim()
  end

  defp reviewer_line(%{username: username, type: "contributor", metadata: %{recent_commit_count: recent_commit_count, total_commit_count: total_commit_count}}) do
    relevant_activity_days =
      :dispatch
      |> Application.get_env(Dispatch.Repositories.Contributors)
      |> Keyword.get(:relevant_activity_days)

    "* @#{username} (contributor with `#{recent_commit_count}` commits in the last #{relevant_activity_days} days and `#{total_commit_count}` commits overall)\n"
  end

  defp reviewer_line(%{username: username, type: "stack", metadata: %{stack: stack}}) do
    "* @#{username} (reviewer for the `#{stack}` stack)\n"
  end

  defp reviewer_line(%{username: username, type: "learner", metadata: %{stack: stack}}) do
    "* @#{username} (learner for the `#{stack}` stack)\n"
  end

  defp reviewer_line(%{username: username, type: type}) do
    "* @#{username} (#{type})\n"
  end
end
