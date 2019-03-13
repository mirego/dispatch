defmodule Dispatch.Application do
  @moduledoc """
  Main entry point of the app
  """

  use Application

  alias Dispatch.Settings.JSONStaticFileClient
  alias DispatchWeb.Endpoint

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Endpoint, []),
      supervisor(JSONStaticFileClient, [])
    ]

    opts = [strategy: :one_for_one, name: Dispatch.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
