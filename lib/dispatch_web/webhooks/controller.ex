defmodule DispatchWeb.Webhooks.Controller do
  use Phoenix.Controller

  def create(conn, %{"action" => "opened", "pull_request" => %{"title" => "WIP " <> _}}), do: json(conn, %{success: true, noop: true})
  def create(conn, %{"action" => "opened", "pull_request" => %{"title" => "WIP:" <> _}}), do: json(conn, %{success: true, noop: true})
  def create(conn, %{"action" => "opened", "pull_request" => %{"title" => "[WIP]" <> _}}), do: json(conn, %{success: true, noop: true})

  def create(conn, %{"action" => "opened", "pull_request" => %{"user" => %{"type" => "Bot"}}}), do: json(conn, %{success: true, noop: true})

  def create(conn, %{"action" => "opened", "repository" => %{"owner" => %{"login" => repo_owner}}} = params) do
    github_organization_login = github_organization_login()

    case repo_owner do
      ^github_organization_login ->
        do_create(conn, params)

      _ ->
        json(conn, %{success: true, noop: true})
    end
  end

  def create(conn, _), do: json(conn, %{success: true, noop: true})

  defp do_create(conn, params) do
    pull_request_number = get_in(params, ["number"])
    author = get_in(params, ["pull_request", "user", "login"])
    repo = get_in(params, ["repository", "full_name"])

    stacks = Dispatch.extract_from_params(params)
    disable_learners = string_to_boolean(Map.get(params, "disable_learners"))
    selected_users = Dispatch.fetch_selected_users(repo, stacks, author, disable_learners)

    repo
    |> Dispatch.request_reviewers(pull_request_number, selected_users)
    |> case do
      :ok ->
        json(conn, %{success: true, noop: false, reviewers: selected_users})

      :error ->
        json(conn, %{success: false, noop: false})
    end
  end

  defp github_organization_login, do: Application.get_env(:dispatch, DispatchWeb.Webhooks)[:github_organization_login]

  defp string_to_boolean("true"), do: true
  defp string_to_boolean("1"), do: true
  defp string_to_boolean(_), do: false
end
