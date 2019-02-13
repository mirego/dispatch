defmodule DispatchWeb.Router do
  use Phoenix.Router
  use Plug.ErrorHandler
  use Sentry.Plug

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", DispatchWeb do
    pipe_through(:api)

    post("/webhooks", Webhooks.Controller, :create)
    get("/health", Health.Controller, :index)
    get("/", Home.Controller, :index)
  end
end
