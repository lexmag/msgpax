defmodule Msgpax.UnpackError do
  @moduledoc """
  Raised when there's an error in de-serializing some data into an Elixir term.
  """

  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason do
      {:excess_bytes, bin} ->
        "found excess bytes: #{inspect(bin)}"
      {:bad_format, bin} ->
        "bad format: #{inspect(bin)}"
      :incomplete ->
        "given binary is incomplete"
      {:not_supported_ext, type} ->
        "extension type is not supported: #{type}"
      {:ext_unpack_failure, type, module, data} ->
        "module #{inspect(module)} could not unpack data (extension type #{type}): #{inspect(data)}"
    end
  end
end

defmodule Msgpax.Unpacker do
  @moduledoc false

  def unpack(<<buffer::bits>>, options) do
    unpack(buffer, [], options)
  end

  formats = %{
    quote(do: [0xC0]) => {:value, quote(do: nil)},
    quote(do: [0xC2]) => {:value, quote(do: false)},
    quote(do: [0xC3]) => {:value, quote(do: true)},

    # String
    quote(do: [0b101::3, length::5, value::size(length)-bytes]) => {:value, quote(do: value)},
    quote(do: [0xD9, length::integer, value::size(length)-bytes]) => {:value, quote(do: value)},
    quote(do: [0xDA, length::16-integer, value::size(length)-bytes]) => {:value, quote(do: value)},
    quote(do: [0xDB, length::32-integer, value::size(length)-bytes]) => {:value, quote(do: value)},

    # Binary
    quote(do: [0xC4, len::integer, val::size(len)-bytes]) => {:call, quote(do: unpack_binary(val))},
    quote(do: [0xC5, len::16-integer, val::size(len)-bytes]) => {:call, quote(do: unpack_binary(val))},
    quote(do: [0xC6, len::32-integer, val::size(len)-bytes]) => {:call, quote(do: unpack_binary(val))},

    # Float
    quote(do: [0xCA, val::32-big-float]) => {:value, quote(do: val)},
    quote(do: [0xCB, val::64-big-float]) => {:value, quote(do: val)},

    # Integer
    quote(do: [0::1, val::7]) => {:value, quote(do: val)},
    quote(do: [0xCC, val]) => {:value, quote(do: val)},
    quote(do: [0xCD, val::16]) => {:value, quote(do: val)},
    quote(do: [0xCE, val::32]) => {:value, quote(do: val)},
    quote(do: [0xCF, val::64]) => {:value, quote(do: val)},
    quote(do: [0b111::3, val::5]) => {:value, quote(do: val - 0b100000)},
    quote(do: [0xD0, val::signed-integer]) => {:value, quote(do: val)},
    quote(do: [0xD1, val::16-signed-integer]) => {:value, quote(do: val)},
    quote(do: [0xD2, val::32-signed-integer]) => {:value, quote(do: val)},
    quote(do: [0xD3, val::64-signed-integer]) => {:value, quote(do: val)},

    # Array
    quote(do: [0b1001::4, len::4]) => {:call, quote(do: unpack_list(len))},
    quote(do: [0xDC, len::16]) => {:call, quote(do: unpack_list(len))},
    quote(do: [0xDD, len::32]) => {:call, quote(do:  unpack_list(len))},

    # Map
    quote(do: [0b1000::4, len::4]) => {:call, quote(do: unpack_map(len))},
    quote(do: [0xDE, len::16]) => {:call, quote(do: unpack_map(len))},
    quote(do: [0xDF, len::32]) => {:call, quote(do: unpack_map(len))},

    # Extension
    quote(do: [0xD4, type, val::1-bytes]) => {:call, quote(do: unpack_ext(type, val))},
    quote(do: [0xD5, type, val::2-bytes]) => {:call, quote(do: unpack_ext(type, val))},
    quote(do: [0xD6, type, val::4-bytes]) => {:call, quote(do: unpack_ext(type, val))},
    quote(do: [0xD7, type, val::8-bytes]) => {:call, quote(do: unpack_ext(type, val))},
    quote(do: [0xD8, type, val::16-bytes]) => {:call, quote(do: unpack_ext(type, val))},
    quote(do: [0xC7, len, type, val::size(len)-bytes]) => {:call, quote(do:  unpack_ext(type, val))},
    quote(do: [0xC8, len::16, type, val::size(len)-bytes]) => {:call, quote(do:  unpack_ext(type, val))},
    quote(do: [0xC9, len::32, type, val::size(len)-bytes]) => {:call, quote(do:  unpack_ext(type, val))},
  }

  import Macro, only: [pipe: 3]

  for {format, {:value, value}} <- formats do
    defp unpack(<<unquote_splicing(format), rest::bits>>, [], options) do
      unpack(rest, [unquote(value)], options)
    end
  end

  for {format, {:call, call}} <- formats do
    rest = Macro.var(:rest, nil)
    options = Macro.var(:options, nil)
    defp unpack(<<unquote_splicing(format), rest::bits>>, [], options) do
      unquote(pipe(rest, pipe([], pipe(options, pipe([], call, 0), 0), 0), 0))
    end
  end

  defp unpack(<<byte, _::bits>>, [], _options) do
    throw {:bad_format, byte}
  end

  defp unpack(<<_::bits>>, [], _options) do
    throw :incomplete
  end

  defp unpack(buffer, [value], _options) do
    {value, buffer}
  end

  defp unpack_binary(<<buffer::bits>>, result, %{binary: true} = options, outer, value) do
    unpack_continue(buffer, [Msgpax.Bin.new(value) | result], options, outer)
  end

  defp unpack_binary(<<buffer::bits>>, result, options, outer, value) do
    unpack_continue(buffer, [value | result], options, outer)
  end

  defp unpack_list(<<buffer::bits>>, result, options, outer, length) do
    unpack_collection(buffer, result, options, outer, 0, length, :list)
  end

  for {format, {:value, value}} <- formats do
    defp unpack_collection(<<unquote_splicing(format), rest::bits>>, result, options, outer, index, length, kind) when index < length do
      unpack_collection(rest, [unquote(value) | result], options, outer, index + 1, length, kind)
    end
  end

  for {format, {:call, call}} <- formats do
    rest = Macro.var(:rest, nil)
    result = Macro.var(:result, nil)
    options = Macro.var(:options, nil)
    outer = Macro.var(:outer, nil)
    defp unpack_collection(<<unquote_splicing(format), rest::bits>>, result, options, outer, index, length, kind) when index < length do
      outer = [{kind, index, length} | outer]
      unquote(pipe(rest, pipe(result, pipe(options, pipe(outer, call, 0), 0), 0), 0))
    end
  end

  defp unpack_collection(<<buffer::bits>>, result, options, outer, count, count, kind) do
    unpack_continue(buffer, build_collection(result, count, kind), options, outer)
  end

  defp unpack_map(<<buffer::bits>>, result, options, outer, length) do
    unpack_collection(buffer, result, options, outer, 0, length * 2, :map)
  end

  defp unpack_ext(<<buffer::bits>>, result, options, outer, type, data) do
    if type in 0..127 do
      unpack_continue(buffer, [unpack_ext(type, data, options) | result], options, outer)
    else
      throw {:not_supported_ext, type}
    end
  end

  defp unpack_ext(type, data, %{ext: module}) when is_atom(module) do
    case module.unpack(Msgpax.Ext.new(type, data)) do
      {:ok, result} ->
        result
      :error ->
        throw {:ext_unpack_failure, type, module, data}
    end
  end

  defp unpack_ext(type, data, _options) do
    Msgpax.Ext.new(type, data)
  end

  defp unpack_continue(<<buffer::bits>>, result, options, [{kind, index, length} | outer]) do
    unpack_collection(buffer, result, options, outer, index + 1, length, kind)
  end

  defp unpack_continue(<<buffer::bits>>, result, options, []) do
    unpack(buffer, result, options)
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
