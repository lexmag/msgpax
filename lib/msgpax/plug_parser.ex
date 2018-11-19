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

    def parse(%Plug.Conn{} = conn, "application", "msgpack", _headers, {msgpax_options, options}) do
      case read_body(conn, options) do
        {:ok, <<>>, conn} ->
          {:next, conn}

        {:ok, body, conn} ->
          {:ok, unpack_body(body, msgpax_options), conn}

        {:more, _partial_body, conn} ->
          {:error, :too_large, conn}
      end
    end

    def parse(%Plug.Conn{} = conn, _type, _subtype, _headers, _opts) do
      {:next, conn}
    end

    def init(options) do
      Keyword.pop(options, :msgpax, [])
    end

    defp unpack_body(body, options) do
      case Msgpax.unpack!(body, options) do
        data when is_map(data) -> data
        data -> %{"_msgpack" => data}
      end
    rescue
      exception in [Msgpax.UnpackError] ->
        raise Plug.Parsers.ParseError, exception: exception
    end
  end
end
