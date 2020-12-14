use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :dispatch, Dispatch.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

config :dispatch, DispatchWeb.Webhooks, github_organization_login: "mirego"

config :dispatch, Dispatch,
  repositories_client: Dispatch.Repositories.MockClient,
  settings_client: Dispatch.Settings.MockClient,
  absence_io_client: Dispatch.AbsenceIO.MockClient

config :dispatch, Dispatch.Repositories.Contributors, relevant_activity_days: 90

config :dispatch, Dispatch.Repositories.GitHubClient, retry_delay: 0
config :dispatch, Dispatch.AbsenceIO.Client, ical_feed_url: "https://example.com/foo.ical"
config :dispatch, Dispatch.Settings.JSONStaticFileClient, configuration_file_url: "https://s3/configuration.json"
