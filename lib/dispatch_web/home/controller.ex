defmodule DispatchWeb.Home.Controller do
  use Phoenix.Controller

  def index(conn, _) do
    json(conn, %{
      dispatch: "🦀",
      stacks: settings_client().stacks()
    })
  end

  defp settings_client, do: Application.get_env(:dispatch, Dispatch)[:settings_client]
end
