use Mix.Config

defmodule Environment do
  @moduledoc """
  This modules provdes various helpers to handle data stored
  in environment variables (obtained via `System.get_env/1`).
  """

  def get(key), do: System.get_env(key)

  def get_boolean(key) do
    key
    |> get()
    |> parse_boolean()
  end

  def get_integer(key, default \\ 0) do
    key
    |> get()
    |> parse_integer(default)
  end

  def exists?(key) do
    key
    |> get()
    |> case do
      "" -> false
      nil -> false
      _ -> true
    end
  end

  defp parse_boolean("true"), do: true
  defp parse_boolean("1"), do: true
  defp parse_boolean(_), do: false

  defp parse_integer(value, _) when is_bitstring(value), do: String.to_integer(value)
  defp parse_integer(_, default), do: default
end

{force_ssl, endpoint_url} =
  if Environment.get_boolean("FORCE_SSL") do
    {true, [schema: "https", port: 443, host: Environment.get("CANONICAL_HOST")]}
  else
    {false, [schema: "http", port: 80, host: Environment.get("CANONICAL_HOST")]}
  end

# Configures the endpoint
config :dispatch, DispatchWeb.Endpoint,
  http: [port: Environment.get("PORT")],
  url: endpoint_url,
  secret_key_base: Environment.get("SECRET_KEY_BASE"),
  render_errors: [view: DispatchWeb.Errors.View, accepts: ~w(html json)],
  pubsub: [name: Dispatch.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures the Phoenix server
config :phoenix, :json_library, Poison

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure SSL
config :dispatch,
  force_ssl: force_ssl,
  canonical_host: Environment.get("CANONICAL_HOST")

# Configure Basic Auth
if Environment.exists?("BASIC_AUTH_USERNAME") do
  config :dispatch,
    basic_auth: [
      username: Environment.get("BASIC_AUTH_USERNAME"),
      password: Environment.get("BASIC_AUTH_PASSWORD")
    ]
end

# Configure Sentry
config :sentry,
  dsn: Environment.get("SENTRY_DSN"),
  environment_name: Environment.get("SENTRY_ENVIRONMENT_NAME"),
  included_environments: [:prod],
  use_error_logger: true,
  root_source_code_path: File.cwd!(),
  enable_source_code_context: true

# Configure Webhooks
config :dispatch, DispatchWeb.Webhooks, github_organization_login: Environment.get("GITHUB_ORGANIZATION_LOGIN")

# Configure clients
config :dispatch, Dispatch,
  repositories_client: Dispatch.Repositories.GitHubClient,
  settings_client: Dispatch.Settings.JSONStaticFileClient,
  absences_client: Dispatch.Absences.AbsenceIOClient

config :dispatch, Dispatch.Repositories.Contributors, relevant_activity_days: 90

config :dispatch, Dispatch.Repositories.GitHubClient,
  access_token: Environment.get("GITHUB_ACCESS_TOKEN"),
  retry_delay: 1000

config :dispatch, Dispatch.Absences.AbsenceIOClient, ical_feed_url: Environment.get("ABSENCEIO_ICAL_FEED_URL")

config :dispatch, Dispatch.Settings.JSONStaticFileClient, configuration_file_url: Environment.get("CONFIGURATION_FILE_URL")
