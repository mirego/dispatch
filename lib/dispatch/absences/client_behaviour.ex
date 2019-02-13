defmodule Dispatch.Absences.ClientBehaviour do
  @callback fetch_absents :: list(ExIcal.Event.t())
end
