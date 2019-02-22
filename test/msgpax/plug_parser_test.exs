defmodule Msgpax.PlugParserTest do
  use ExUnit.Case
  use Plug.Test

  test "body with a MessagePack-encoded map" do
    conn = conn(:post, "/", Msgpax.pack!(%{hello: "world"}, iodata: false))

    assert {:ok, %{"hello" => "world"}, _conn} = parse(conn, [])
  end

  test "body with a MessagePack-encoded non-map term" do
    conn = conn(:post, "/", Msgpax.pack!(100, iodata: false))

    assert {:ok, %{"_msgpack" => 100}, _conn} = parse(conn, [])
  end

  test "body with a MessagePack-encoded struct" do
    {:ok, datetime, 0} = DateTime.from_iso8601("2000-01-02T03:04:05Z")
    conn = conn(:post, "/", Msgpax.pack!(datetime, iodata: false))

    assert {:ok, unpacked, _conn} = parse(conn, [])
    assert unpacked == %{"_msgpack" => datetime}
  end

  test "accepts an MFA for options" do
    binary = Msgpax.Bin.new("hello world")
    conn = conn(:post, "/", Msgpax.pack!(binary, iodata: false))

    assert {:ok, unpacked, _conn} = parse(conn, unpacker: {Msgpax, :unpack!, [[binary: true]]})
    assert unpacked == %{"_msgpack" => binary}
  end

  test "accepts a module for options" do
    conn = conn(:post, "/", Msgpax.pack!(100, iodata: false))

    assert {:ok, unpacked, _conn} = parse(conn, unpacker: Msgpax)
    assert {:ok, ^unpacked, _conn} = parse(conn, [])
  end

  test "request with a content-type other than application/msgpack" do
    conn = conn(:post, "/", Msgpax.pack!(100, iodata: false))
    options = Msgpax.PlugParser.init([])

    assert {:next, ^conn} = Msgpax.PlugParser.parse(conn, "application", "json", %{}, options)
  end

  test "bad MessagePack-encoded body" do
    conn = conn(:post, "/", "bad body")

    assert_raise Plug.Parsers.ParseError, ~r/found excess bytes/, fn ->
      parse(conn, [])
    end
  end

  test "empty body" do
    conn = conn(:post, "/", "")

    assert_raise Plug.Parsers.ParseError, ~r/given binary is incomplete/, fn ->
      parse(conn, [])
    end
  end

  defp parse(conn, options) do
    options = Msgpax.PlugParser.init(options)
    Msgpax.PlugParser.parse(conn, "application", "msgpack", %{}, options)
  end
end
