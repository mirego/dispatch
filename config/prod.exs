use Mix.Config

# Do not print debug messages in production

config :dispatch, DispatchWeb.Endpoint,
  root: '.',
  server: true,
  version: Application.spec(:dispatch, :vsn)

config :logger, level: :info
