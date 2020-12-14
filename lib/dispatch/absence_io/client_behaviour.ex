defmodule Dispatch.AbsenceIO.ClientBehaviour do
  @callback fetch_absents :: list(ExIcal.Event.t())
end
