defmodule DispatchWeb.Webhooks.Controller do
  use Phoenix.Controller

  def create(conn, %{"action" => "opened", "pull_request" => %{"title" => "WIP " <> _}}), do: json(conn, %{success: true, noop: true})
  def create(conn, %{"action" => "opened", "pull_request" => %{"title" => "WIP:" <> _}}), do: json(conn, %{success: true, noop: true})
  def create(conn, %{"action" => "opened", "pull_request" => %{"title" => "[WIP]" <> _}}), do: json(conn, %{success: true, noop: true})

  def create(
        conn,
        %{
          "number" => pull_request_number,
          "action" => "opened",
          "pull_request" => %{"user" => %{"login" => author}},
          "repository" => %{"full_name" => repo, "owner" => %{"login" => "mirego"}}
        } = params
      ) do
    stacks = Dispatch.extract_from_params(params)
    selected_users = Dispatch.fetch_selected_users(repo, stacks, author)

    repo
    |> Dispatch.request_reviewers(pull_request_number, selected_users)
    |> case do
      :ok ->
        json(conn, %{success: true, noop: false, reviewers: selected_users})

      :error ->
        json(conn, %{success: false, noop: false})
    end
  end

  def create(conn, _), do: json(conn, %{success: true, noop: true})
end
