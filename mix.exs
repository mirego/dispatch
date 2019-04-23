defmodule Dispatch.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dispatch,
      version: "1.0.3",
      elixir: "1.8.1",
      erlang: "21.2.5",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: ["test"],
      test_pattern: "**/*_test.exs",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.detail": :test, "coveralls.post": :test, "coveralls.html": :test],
      compilers: [:phoenix] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Dispatch.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix
      {:phoenix, "~> 1.4.0"},

      # Authentication
      {:basic_auth, "~> 2.2.4"},

      # HTTP server
      {:plug_cowboy, "~> 2.0"},
      {:plug, "~> 1.7"},
      {:plug_canonical_host, "~> 0.3"},
      {:jason, "~> 1.1"},

      # HTTP client
      {:httpoison, "~> 0.13"},
      {:hackney, "~> 1.13"},

      # Errors
      {:sentry, "~> 6.2"},

      # Date/time management
      {:timex, "~> 3.1"},

      # iCalendar parser
      {:ex_ical, github: "fazibear/ex_ical"},

      # OTP Release
      {:distillery, "~> 2.0"},

      # Linting
      {:credo, "~> 1.0.0", only: ~w(dev test)a, runtime: false},
      {:credo_envvar, "~> 0.1.0", only: ~w(dev test)a, runtime: false},
      {:credo_filename_consistency, "~> 0.1.0", only: [:dev, :test], runtime: false},

      # Test
      {:mock, "~> 0.2.0", only: :test},
      {:mox, "~> 0.4.0", only: :test},

      # Test coverage
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp aliases do
    [
      "compile.app": ["erlang.check_version", "compile.app"]
    ]
  end
end
