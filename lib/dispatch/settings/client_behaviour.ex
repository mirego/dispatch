defmodule Dispatch.Settings.ClientBehaviour do
  @callback blocklisted_users :: list(Dispatch.Settings.BlocklistedUser.t())
  @callback reviewer_users(String.t()) :: list(Dispatch.Settings.Reviewer.t())
  @callback learner_users(String.t()) :: list(Dispatch.Settings.Learner.t())
  @callback stacks :: list(String.t())
  @callback refresh :: atom()
end
