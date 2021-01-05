if Code.ensure_loaded?(Plug) do
  defmodule Msgpax.PlugParser do
    @moduledoc """
    A `Plug.Parsers` plug for parsing a MessagePack-encoded body.

    Look at the [documentation for
    `Plug.Parsers`](http://hexdocs.pm/plug/Plug.Parsers.html) for more
    information on how to use `Plug.Parsers`.

    This parser accepts the `:unpacker` option to configure how unpacking should be done.
    Its value can either be a module that implements the `unpack!/1` function
    or a module, function, and arguments tuple. Note, the response
    body will be prepended to the given list of arguments before applying.

    ## Examples

        defmodule MyPlugPipeline do
          use Plug.Builder

          plug Plug.Parsers,
               parsers: [Msgpax.PlugParser],
               pass: ["application/msgpack"]

          # Or use the :unpacker option:
          plug Plug.Parsers,
               parsers: [Msgpax.PlugParser],
               pass: ["application/msgpack"],
               unpacker: {Msgpax, :unpack!, [[binary: true]]}

          # ... rest of the pipeline
        end

    """

    @behaviour Plug.Parsers

    import Plug.Conn

    def parse(%Plug.Conn{} = conn, "application", "msgpack", _params, {unpacker, options}) do
      case read_body(conn, options) do
        {:ok, body, conn} ->
          {:ok, unpack(body, unpacker), conn}

        {:more, _partial_body, conn} ->
          {:error, :too_large, conn}
      end
    end

    def parse(%Plug.Conn{} = conn, _type, _subtype, _params, _opts) do
      {:next, conn}
    end

    def init(options) do
      {unpacker, options} = Keyword.pop(options, :unpacker, Msgpax)
      {validate_unpacker!(unpacker), options}
    end

    defp unpack(body, {module, function, extra_args}) do
      try do
        apply(module, function, [body | extra_args])
      rescue
        exception ->
          raise Plug.Parsers.ParseError, exception: exception
      else
        %_{} = data -> %{"_msgpack" => data}
        data when is_map(data) -> data
        data -> %{"_msgpack" => data}
      end
    end

    defp validate_unpacker!({module, function, extra_args} = unpacker)
         when is_atom(module) and is_atom(function) and is_list(extra_args) do
      arity = length(extra_args) + 1

      if Code.ensure_compiled(module) != {:module, module} do
        raise ArgumentError,
              "invalid :unpacker option. The module #{inspect(unpacker)} is not " <>
                "loaded and could not be found"
      end

      if not function_exported?(module, function, arity) do
        raise ArgumentError,
              "invalid :unpacker option. The module #{inspect(module)} must " <>
                "implement #{function}/#{arity}"
      end

      unpacker
    end

    defp validate_unpacker!(unpacker) when is_atom(unpacker) do
      validate_unpacker!({unpacker, :unpack!, []})
    end

    defp validate_unpacker!(unpacker) do
      raise ArgumentError,
            "the :unpacker option expects a module, or a three-element " <>
              "tuple in the form of {module, function, extra_args}, got: #{inspect(unpacker)}"
    end
  end
end
