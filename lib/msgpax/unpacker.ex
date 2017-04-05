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
    def unpack(<<unquote_splicing(format), rest::bytes>>, [], options) do
      unpack(rest, [unquote(value)], options)
    end
  end

  for {format, {:call, call}} <- formats do
    rest = Macro.var(:rest, nil)
    options = Macro.var(:options, nil)
    def unpack(<<unquote_splicing(format), rest::bytes>>, [], options) do
      unquote(pipe(rest, pipe([], pipe(options, pipe([], call, 0), 0), 0), 0))
    end
  end

  def unpack(<<byte, _::bytes>>, [], _options) do
    throw {:bad_format, byte}
  end

  def unpack(<<_::bits>>, [], _options) do
    throw :incomplete
  end

  def unpack(buffer, [value], _options) do
    {value, buffer}
  end

  defp unpack_binary(<<buffer::bytes>>, result, %{binary: true} = options, outer, value) do
    unpack_continue(buffer, [Msgpax.Bin.new(value) | result], options, outer)
  end

  defp unpack_binary(<<buffer::bytes>>, result, options, outer, value) do
    unpack_continue(buffer, [value | result], options, outer)
  end

  def unpack_list(<<buffer::bytes>>, result, options, outer, length) do
    unpack_list(buffer, result, options, outer, 0, length)
  end

  def unpack_list(<<buffer::bytes>>, result, options, outer, count, count) do
    {value, rest} = Enum.split(result, count)
    unpack_continue(buffer, [:lists.reverse(value) | rest], options, outer)
  end

  for {format, {:value, value}} <- formats do
    def unpack_list(<<unquote_splicing(format), rest::bytes>>, result, options, outer, index, length) do
      unpack_list(rest, [unquote(value) | result], options, outer, index + 1, length)
    end
  end

  for {format, {:call, call}} <- formats do
    rest = Macro.var(:rest, nil)
    result = Macro.var(:result, nil)
    options = Macro.var(:options, nil)
    outer = Macro.var(:outer, nil)
    def unpack_list(<<unquote_splicing(format), rest::bytes>>, result, options, outer, index, length) do
      outer = [{index, length} | outer]
      unquote(pipe(rest, pipe(result, pipe(options, pipe(outer, call, 0), 0), 0), 0))
    end
  end

  def unpack_map(<<buffer::bytes>>, result, options, outer, length) do
    unpack_map(buffer, result, options, outer, 0, length, :key)
  end

  def unpack_map(<<buffer::bytes>>, result, options, outer, count, count, :key) do
    {value, rest} = Enum.split(result, count)
    unpack_continue(buffer, [:maps.from_list(value) | rest], options, outer)
  end

  for {format, {:value, value}} <- formats do
    def unpack_map(<<unquote_splicing(format), rest::bytes>>, result, options, outer, index, length, :key) do
      unpack_map(rest, [unquote(value) | result], options, outer, index, length, :value)
    end

    def unpack_map(<<unquote_splicing(format), rest::bytes>>, [key | result], options, outer, index, length, :value) do
      unpack_map(rest, [{key, unquote(value)} | result], options, outer, index + 1, length, :key)
    end
  end

  for {format, {:call, call}} <- formats do
    rest = Macro.var(:rest, nil)
    result = Macro.var(:result, nil)
    options = Macro.var(:options, nil)
    outer = Macro.var(:outer, nil)
    def unpack_map(<<unquote_splicing(format), rest::bytes>>, result, options, outer, index, length, type) do
      outer = [{index, length, type} | outer]
      unquote(pipe(rest, pipe(result, pipe(options, pipe(outer, call, 0), 0), 0), 0))
    end
  end

  defp unpack_ext(<<buffer::bytes>>, result, options, outer, type, data) do
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

  def unpack_continue(<<buffer::bytes>>, result, options, [{index, length} | outer]) do
    unpack_list(buffer, result, options, outer, index + 1, length)
  end

  def unpack_continue(<<buffer::bytes>>, result, options, [{index, length, :key} | outer]) do
    unpack_map(buffer, result, options, outer, index, length, :value)
  end

  def unpack_continue(<<buffer::bytes>>, [{value, key} | result], options, [{index, length, :value} | outer]) do
    unpack_map(buffer, [{key, value} | result], options, outer, index + 1, length, :key)
  end

  def unpack_continue(<<buffer::bytes>>, result, options, []) do
    unpack(buffer, result, options)
  end
end
