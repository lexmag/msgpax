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

          plug Plug.Parsers,
               parsers: [Msgpax.PlugParser],
               pass: ["application/msgpack"]

          # Alternatively, use "unpacker" option which accepts an MFA, to
          # configure how unpacking should be done.
          plug Plug.Parsers,
               parsers: [Msgpax.PlugParser],
               pass: ["application/msgpack"],
               unpacker: {Msgpax, :unpack!, [binary: true, ...]}

          # rest of the pipeline
        end

    """

    @behaviour Plug.Parsers

    import Plug.Conn

    def parse(%Plug.Conn{} = conn, "application", "msgpack", _headers, {unpacker, options}) do
      case read_body(conn, options) do
        {:ok, <<>>, conn} ->
          {:next, conn}

        {:ok, body, conn} ->
          {:ok, unpack_body(body, unpacker), conn}

        {:more, _partial_body, conn} ->
          {:error, :too_large, conn}
      end
    end

    def parse(%Plug.Conn{} = conn, _type, _subtype, _headers, _opts) do
      {:next, conn}
    end

    def init(options) do
      Keyword.pop(options, :unpacker, Msgpax)
    end

    defp unpack_body(body, unpacker) do
      case apply_mfa_or_module(body, unpacker) do
        data when is_map(data) -> data
        data -> %{"_msgpack" => data}
      end
    rescue
      exception ->
        raise Plug.Parsers.ParseError, exception: exception
    end

    defp apply_mfa_or_module(body, unpacker) when is_atom(unpacker) do
      unpacker.unpack!(body)
    end

    defp apply_mfa_or_module(body, {module_name, function_name, extra_args}) do
      apply(module_name, function_name, [body | extra_args])
    end
  end
end
