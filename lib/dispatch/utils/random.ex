defmodule Dispatch.Utils.Random do
  @moduledoc """
  A wrapper to be able to mock `:rand`
  """

  defdelegate uniform(number), to: :rand
end
