defmodule DispatchWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :dispatch

  plug(:canonical_host)
  plug(:force_ssl)
  plug(:basic_auth)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Logger)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(DispatchWeb.Router)

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end

  defp canonical_host(conn, _opts) do
    opts = PlugCanonicalHost.init(canonical_host: Application.get_env(:dispatch, :canonical_host))

    PlugCanonicalHost.call(conn, opts)
  end

  defp force_ssl(conn, _opts) do
    if Application.get_env(:dispatch, :force_ssl) do
      opts = Plug.SSL.init(rewrite_on: [:x_forwarded_proto])

      Plug.SSL.call(conn, opts)
    else
      conn
    end
  end

  defp basic_auth(conn, _opts) do
    basic_auth_config = Application.get_env(:dispatch, :basic_auth)

    if basic_auth_config do
      opts = BasicAuth.init(use_config: {:dispatch, :basic_auth})

      BasicAuth.call(conn, opts)
    else
      conn
    end
  end
end
