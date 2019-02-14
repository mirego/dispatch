defmodule DispatchWeb.Home.ControllerTest do
  use DispatchWeb.ConnCase

  import Mox

  setup :verify_on_exit!

  test "GET /", %{conn: conn} do
    expect(Dispatch.Settings.MockClient, :stacks, fn -> ["foo", "bar"] end)

    conn = get(conn, "/")

    assert json_response(conn, 200) == %{
             "stacks" => ["foo", "bar"],
             "dispatch" => "🦀"
           }
  end
end
