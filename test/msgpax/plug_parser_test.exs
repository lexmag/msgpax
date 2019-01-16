defmodule Msgpax.PlugParserTest do
  use ExUnit.Case
  use Plug.Test

  test "body with a MessagePack-encoded map" do
    conn = conn(:post, "/", Msgpax.pack!(%{hello: "world"}) |> IO.iodata_to_binary())

    assert {:ok, %{"hello" => "world"}, _conn} =
             Msgpax.PlugParser.parse(conn, "application", "msgpack", [], [])
  end

  test "body with a MessagePack-encoded non-map term" do
    conn = conn(:post, "/", Msgpax.pack!(100) |> IO.iodata_to_binary())

    assert {:ok, %{"_msgpack" => 100}, _conn} =
             Msgpax.PlugParser.parse(conn, "application", "msgpack", [], [])
  end

  test "request with a content-type other than application/msgpack" do
    conn = conn(:post, "/", Msgpax.pack!(100) |> IO.iodata_to_binary())
    assert {:next, ^conn} = Msgpax.PlugParser.parse(conn, "application", "json", [], [])
  end

  test "bad MessagePack-encoded body" do
    conn = conn(:post, "/", "bad body")

    assert_raise Plug.Parsers.ParseError, ~r/found excess bytes/, fn ->
      Msgpax.PlugParser.parse(conn, "application", "msgpack", [], [])
    end
  end

  test "empty body" do
    conn = conn(:post, "/", "")

    assert_raise Plug.Parsers.ParseError, ~r/given binary is incomplete/, fn ->
      Msgpax.PlugParser.parse(conn, "application", "msgpack", [], [])
    end
  end
end
