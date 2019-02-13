defmodule DispatchWeb.Health.ControllerTest do
  use DispatchWeb.ConnCase

  import Mox

  setup :verify_on_exit!

  test "GET /health", %{conn: conn} do
    expect(Dispatch.Repositories.MockClient, :ping, fn -> :ok end)

    conn = get(conn, "/health")

    assert json_response(conn, 200) == %{
             "app" => "ok",
             "github" => "ok"
           }
  end
end
