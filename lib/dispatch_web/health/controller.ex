defmodule DispatchWeb.Health.Controller do
  use Phoenix.Controller

  def index(conn, _) do
    json(conn, %{
      app: :ok,
      github: github_client().ping()
    })
  end

  defp github_client, do: Application.get_env(:dispatch, Dispatch)[:repositories_client]
end
