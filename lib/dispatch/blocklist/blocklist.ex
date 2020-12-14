defmodule Dispatch.Blocklist do
  alias Dispatch.Settings

  def users do
    Settings.blocklisted_users()
  end
end
