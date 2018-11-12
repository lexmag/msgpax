defmodule Msgpax.UnpackError do
  @moduledoc """
  Raised when there's an error in de-serializing some data into an Elixir term.
  """

  @type t :: %__MODULE__{
          reason:
            {:excess_bytes, binary}
            | {:invalid_format, integer}
            | :incomplete
            | {:ext_unpack_failure, module, Msgpax.Ext.t()}
        }

  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason do
      {:excess_bytes, bytes} ->
        "found excess bytes: #{inspect(bytes)}"

      {:invalid_format, byte} ->
        "invalid format, first byte: #{byte}"

      :incomplete ->
        "given binary is incomplete"

      {:ext_unpack_failure, module, struct} ->
        "module #{inspect(module)} could not unpack extension: #{inspect(struct)}"
    end
  end
end

defmodule Msgpax.Unpacker do
  @moduledoc false

  def unpack(<<buffer::bits>>, options) do
    unpack(buffer, [], Map.new(options), [], 0, 1)
  end

  primitives = %{
    [quote(do: <<0xC0>>)] => quote(do: nil),
    [quote(do: <<0xC2>>)] => quote(do: false),
    [quote(do: <<0xC3>>)] => quote(do: true),
    # Strings
    [
      quote(do: <<0b101::3, length::5, value::size(length)-bytes>>),
      quote(do: <<0xD9, length::8, value::size(length)-bytes>>),
      quote(do: <<0xDA, length::16, value::size(length)-bytes>>),
      quote(do: <<0xDB, length::32, value::size(length)-bytes>>),

      # Floats
      quote(do: <<0xCA, value::32-float>>),
      quote(do: <<0xCB, value::64-float>>),

      # Integers
      quote(do: <<0::1, value::7>>),
      quote(do: <<0xCC, value::8>>),
      quote(do: <<0xCD, value::16>>),
      quote(do: <<0xCE, value::32>>),
      quote(do: <<0xCF, value::64>>),
      quote(do: <<0xD0, value::8-signed>>),
      quote(do: <<0xD1, value::16-signed>>),
      quote(do: <<0xD2, value::32-signed>>),
      quote(do: <<0xD3, value::64-signed>>)
    ] => quote(do: value),
    # Negative fixint
    [quote(do: <<0b111::3, value::5>>)] => quote(do: value - 0b100000)
  }

  for {formats, value} <- primitives,
      format <- formats do
    defp unpack(<<unquote(format), rest::bits>>, result, options, outer, index, count) do
      result = [unquote(value) | result]
      unpack_continue(rest, result, options, outer, index, count)
    end
  end

  lists = [
    quote(do: <<0b1001::4, length::4>>),
    quote(do: <<0xDC, length::16>>),
    quote(do: <<0xDD, length::32>>)
  ]

  for format <- lists do
    defp unpack(<<unquote(format), rest::bits>>, result, options, outer, index, count) do
      case unquote(quote(do: length)) do
        0 ->
          unpack_continue(rest, [[] | result], options, outer, index, count)

        length ->
          unpack(rest, result, options, [:list, index, count | outer], 0, length)
      end
    end
  end

  maps = [
    quote(do: <<0b1000::4, length::4>>),
    quote(do: <<0xDE, length::16>>),
    quote(do: <<0xDF, length::32>>)
  ]

  for format <- maps do
    defp unpack(<<unquote(format), rest::bits>>, result, options, outer, index, count) do
      case unquote(quote(do: length)) do
        0 ->
          unpack_continue(rest, [%{} | result], options, outer, index, count)

        length ->
          unpack(rest, result, options, [:map, index, count | outer], 0, length * 2)
      end
    end
  end

  binaries = [
    quote(do: <<0xC4, length::8, content::size(length)-bytes>>),
    quote(do: <<0xC5, length::16, content::size(length)-bytes>>),
    quote(do: <<0xC6, length::32, content::size(length)-bytes>>)
  ]

  for format <- binaries do
    defp unpack(<<unquote(format), rest::bits>>, result, options, outer, index, count) do
      value = unpack_binary(unquote(quote(do: content)), options)
      unpack_continue(rest, [value | result], options, outer, index, count)
    end
  end

  extensions = [
    quote(do: <<0xD4, type, content::1-bytes>>),
    quote(do: <<0xD5, type, content::2-bytes>>),
    quote(do: <<0xD6, type, content::4-bytes>>),
    quote(do: <<0xD7, type, content::8-bytes>>),
    quote(do: <<0xD8, type, content::16-bytes>>),
    quote(do: <<0xC7, length::8, type, content::size(length)-bytes>>),
    quote(do: <<0xC8, length::16, type, content::size(length)-bytes>>),
    quote(do: <<0xC9, length::32, type, content::size(length)-bytes>>)
  ]

  for format <- extensions do
    defp unpack(<<unquote(format), rest::bits>>, result, options, outer, index, count) do
      value = unpack_ext(unquote(quote(do: type)), unquote(quote(do: content)), options)
      unpack_continue(rest, [value | result], options, outer, index, count)
    end
  end

  defp unpack(<<byte, _::bits>>, _result, _options, _outer, _index, _count) do
    throw({:invalid_format, byte})
  end

  defp unpack(<<_::bits>>, _result, _options, _outer, _index, _count) do
    throw(:incomplete)
  end

  @compile {:inline, [unpack_continue: 6]}

  defp unpack_continue(rest, result, options, outer, index, count) do
    case index + 1 do
      ^count ->
        unpack_continue(rest, result, options, outer, count)

      index ->
        unpack(rest, result, options, outer, index, count)
    end
  end

  defp unpack_continue(<<buffer::bits>>, result, options, [kind, index, length | outer], count) do
    result = build_collection(result, count, kind)

    case index + 1 do
      ^length ->
        unpack_continue(buffer, result, options, outer, length)

      index ->
        unpack(buffer, result, options, outer, index, length)
    end
  end

  defp unpack_continue(<<buffer::bits>>, [value], _options, [], 1) do
    {value, buffer}
  end

  defp unpack_binary(content, %{binary: true}) do
    Msgpax.Bin.new(content)
  end

  defp unpack_binary(content, _options) do
    content
  end

  defp unpack_ext(type, content, options) do
    if type < 128 do
      type
      |> Msgpax.Ext.new(content)
      |> unpack_ext(options)
    else
      type
      |> Kernel.-(256)
      |> Msgpax.ReservedExt.new(content)
      |> unpack_ext(%{ext: Msgpax.ReservedExt})
    end
  end

  @compile {:inline, [unpack_ext: 2]}

  defp unpack_ext(struct, %{ext: module}) when is_atom(module) do
    case module.unpack(struct) do
      {:ok, result} ->
        result

      :error ->
        throw({:ext_unpack_failure, module, struct})
    end
  end

  defp unpack_ext(struct, _options) do
    struct
  end

  @compile {:inline, [build_collection: 3]}

  defp build_collection(result, count, :list) do
    build_list(result, [], count)
  end

  defp build_collection(result, count, :map) do
    build_map(result, [], count)
  end

  defp build_list(result, list, 0) do
    [list | result]
  end

  defp build_list([item | rest], list, count) do
    build_list(rest, [item | list], count - 1)
  end

  defp build_map(result, pairs, 0) do
    [:maps.from_list(pairs) | result]
  end

  defp build_map([value, key | rest], pairs, count) do
    build_map(rest, [{key, value} | pairs], count - 2)
  end
end
