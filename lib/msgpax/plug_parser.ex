if Code.ensure_compiled?(Plug) do
  defmodule Msgpax.PlugParser do
    @moduledoc """
    A `Plug.Parsers` plug for parsing a MessagePack-encoded body.

    Look at the [documentation for
    `Plug.Parsers`](http://hexdocs.pm/plug/Plug.Parsers.html) for more
    information on how to use `Plug.Parsers`.

    ## Examples

        defmodule MyPlugPipeline do
          use Plug.Builder

          plug Plug.Parsers, parsers: [Msgpax.PlugParser], pass: ["application/msgpack"]
          # rest of the pipeline
        end

    """

    @behaviour Plug.Parsers

    import Plug.Conn

    def parse(%Plug.Conn{} = conn, "application", "msgpack", _headers, opts) do
      case read_body(conn, opts) do
        {:ok, body, conn} ->
          {:ok, unpack_body(body), conn}
        {:more, _partial_body, conn} ->
          {:error, :too_large, conn}
      end
    end

    def parse(%Plug.Conn{} = conn, _type, _subtype, _headers, _opts) do
      {:next, conn}
    end

    defp unpack_body(body) do
      case Msgpax.unpack!(body) do
        data when is_map(data) -> data
        data -> %{"_msgpack" => data}
      end
    rescue
      exception in [Msgpax.UnpackError] ->
        raise Plug.Parsers.ParseError, exception: exception
    end
  end
end
