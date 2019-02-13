defmodule Dispatch.Repositories.ClientBehaviour do
  @callback ping :: :ok | :error
  @callback fetch_requestable_users(String.t()) :: list(String.t())
  @callback fetch_contributors(String.t()) :: list(Dispatch.Repositories.Contributor.t())
  @callback request_reviewers(String.t(), Integer.t(), List.t()) :: :ok | :error
  @callback create_request_comment(String.t(), Integer.t(), List.t()) :: :ok | :error
end
