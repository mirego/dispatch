defmodule Dispatch.AbsenceIOTest do
  use ExUnit.Case

  import Mox

  alias Dispatch.Absences
  alias Timex.Duration

  setup :verify_on_exit!

  test "absent_fullnames/0 retrieve users currently absent" do
    now = Timex.now()

    events = [
      %ExIcal.Event{
        start: Timex.subtract(now, Duration.from_minutes(60)),
        end: Timex.add(now, Duration.from_minutes(60)),
        summary: " Out of Office - supaidaman"
      },
      %ExIcal.Event{
        start: Timex.subtract(now, Duration.from_days(1)),
        end: Timex.add(now, Duration.from_days(1)),
        summary: "Out of Office - Swamp Thing"
      },
      %ExIcal.Event{
        start: Timex.add(now, Duration.from_days(7)),
        end: Timex.add(now, Duration.from_days(14)),
        summary: " Out of Office - Not absent"
      }
    ]

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> events end)

    results = Absences.absent_fullnames()

    assert results == ["supaidaman", "swamp thing"]
  end

  test "absent_fullnames/0 ignore unknown summary pattern" do
    now = Timex.now()

    events = [
      %ExIcal.Event{
        start: Timex.subtract(now, Duration.from_minutes(60)),
        end: Timex.add(now, Duration.from_minutes(60)),
        summary: " Out of Office - John Doe"
      },
      %ExIcal.Event{
        start: Timex.subtract(now, Duration.from_days(1)),
        end: Timex.add(now, Duration.from_days(1)),
        summary: nil
      },
      %ExIcal.Event{
        start: Timex.add(now, Duration.from_days(7)),
        end: Timex.add(now, Duration.from_days(14)),
        summary: "Unknown summary pattern"
      }
    ]

    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> events end)

    results = Absences.absent_fullnames()

    assert results == ["john doe"]
  end

  test "absents/0 return empty list on no absents" do
    expect(Dispatch.Absences.MockClient, :fetch_absents, fn -> [] end)

    results = Absences.absent_fullnames()

    assert results == []
  end
end
