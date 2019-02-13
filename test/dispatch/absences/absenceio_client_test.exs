defmodule Dispatch.Absences.AbsenceIOClientTest do
  use ExUnit.Case, async: false

  import Mock

  alias Dispatch.Absences.AbsenceIOClient

  defp ical_feed_url, do: Application.get_env(:dispatch, AbsenceIOClient)[:ical_feed_url]

  test "fetch_absents/0" do
    ical = """
    BEGIN:VCALENDAR
    BEGIN:VEVENT
    UID: absence.io-event-a4a722e5649b405e888e78d99ec62d11
    DTSTAMP:20180711T000000
    STATUS:CONFIRMED
    DTSTART;VALUE=DATE:20180216
    DTEND;VALUE=DATE:20180217
    SUMMARY: Out of Office - Peter Parker
    DESCRIPTION;ENCODING=QUOTED-PRINTABLE:Peter Parker will be away from the office between 16 Feb, 2018 00:00 and 17 Feb, 2018 00:00
    END:VEVENT
    BEGIN:VEVENT
    UID: absence.io-event-a8c2748a1c784c4a8b2e40302cd98765
    DTSTAMP:20180709T000000
    STATUS:CONFIRMED
    DTSTART;VALUE=DATE:20180729
    DTEND;VALUE=DATE:20180820
    SUMMARY: Out of Office - Clark Kent
    DESCRIPTION;ENCODING=QUOTED-PRINTABLE:Clark Kent will be away from the office between 29 Jul, 2018 00:00 and 20 Aug, 2018 00:00
    END:VEVENT
    END:VCALENDAR
    """

    url = ical_feed_url()

    with_mock HTTPoison, get: fn ^url -> {:ok, %{body: ical}} end do
      result = AbsenceIOClient.fetch_absents()

      assert result == [
               %ExIcal.Event{
                 categories: nil,
                 description: nil,
                 end: datetime_from_iso8601("2018-08-20 00:00:00Z"),
                 rrule: nil,
                 stamp: datetime_from_iso8601("2018-07-09 00:00:00Z"),
                 start: datetime_from_iso8601("2018-07-29 00:00:00Z"),
                 summary: " Out of Office - Clark Kent",
                 uid: " absence.io-event-a8c2748a1c784c4a8b2e40302cd98765"
               },
               %ExIcal.Event{
                 categories: nil,
                 description: nil,
                 end: datetime_from_iso8601("2018-02-17 00:00:00Z"),
                 rrule: nil,
                 stamp: datetime_from_iso8601("2018-07-11 00:00:00Z"),
                 start: datetime_from_iso8601("2018-02-16 00:00:00Z"),
                 summary: " Out of Office - Peter Parker",
                 uid: " absence.io-event-a4a722e5649b405e888e78d99ec62d11"
               }
             ]
    end
  end

  test "fetch_absents/0 return empty list when no absents" do
    ical = """
    BEGIN:VCALENDAR
    END:VCALENDAR
    """

    url = ical_feed_url()

    with_mock HTTPoison, get: fn ^url -> {:ok, %{body: ical}} end do
      result = AbsenceIOClient.fetch_absents()

      assert result == []
    end
  end

  test "fetch_absents/0 return empty list on error" do
    url = ical_feed_url()

    with_mock HTTPoison, get: fn ^url -> {:error, "Fail"} end do
      result = AbsenceIOClient.fetch_absents()

      assert result == []
    end
  end

  defp datetime_from_iso8601(iso_date), do: iso_date |> DateTime.from_iso8601() |> elem(1)
end
