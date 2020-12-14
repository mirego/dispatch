defmodule Dispatch.Settings.ClientBehaviour do
  @callback blocklisted_users :: list(Dispatch.Settings.BlocklistedUser.t())
  @callback expert_users(String.t()) :: list(Dispatch.Settings.Expert.t())
  @callback learner_users(String.t()) :: list(Dispatch.Settings.Learner.t())
  @callback stacks :: list(String.t())
  @callback refresh :: atom()
end
