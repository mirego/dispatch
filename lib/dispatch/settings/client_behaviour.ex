defmodule Dispatch.Settings.ClientBehaviour do
  @callback blacklisted_users :: list(Dispatch.Settings.BlacklistedUser.t())
  @callback expert_users(String.t()) :: list(Dispatch.Settings.Expert.t())
  @callback learner_users(String.t()) :: list(Dispatch.Settings.Learner.t())
  @callback stacks :: list(String.t())
  @callback refresh :: boolean()
end
