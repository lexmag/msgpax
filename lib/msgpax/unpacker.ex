defmodule Msgpax.Unpacker.Unpack do
  @moduledoc false

  import Macro, only: [pipe: 3]

  defmacro defunpack(format, to: value) do
    quote do
      def unpack(<<unquote_splicing(format), rest::bytes>>, _opts) do
        {unquote(value), rest}
      end
    end
  end

  defmacro defunpack(format, do: block) do
    quote do
      def unpack(<<unquote_splicing(format), rest::bytes>>, opts) do
        unquote(pipe(quote(do: rest), pipe(quote(do: opts), block, 0), 0))
      end
    end
  end
end

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

  import __MODULE__.Unpack

  defunpack [0xC0], to: nil
  defunpack [0xC2], to: false
  defunpack [0xC3], to: true

  # String
  defunpack [0b101::3, len::5, val::size(len)-bytes], to: val
  defunpack [0xD9, len::integer, val::size(len)-bytes], to: val
  defunpack [0xDA, len::16-integer, val::size(len)-bytes], to: val
  defunpack [0xDB, len::32-integer, val::size(len)-bytes], to: val

  # Binary
  defunpack [0xC4, len::integer, val::size(len)-bytes], do: unpack_binary(val)
  defunpack [0xC5, len::16-integer, val::size(len)-bytes], do: unpack_binary(val)
  defunpack [0xC6, len::32-integer, val::size(len)-bytes], do: unpack_binary(val)

  # Float
  defunpack [0xCA, val::32-big-float], to: val
  defunpack [0xCB, val::64-big-float], to: val

  # Integer
  defunpack [0::1, val::7], to: val
  defunpack [0xCC, val], to: val
  defunpack [0xCD, val::16], to: val
  defunpack [0xCE, val::32], to: val
  defunpack [0xCF, val::64], to: val

  defunpack [0b111::3, val::5], to: val - 0b100000
  defunpack [0xD0, val::signed-integer], to: val
  defunpack [0xD1, val::16-signed-integer], to: val
  defunpack [0xD2, val::32-signed-integer], to: val
  defunpack [0xD3, val::64-signed-integer], to: val

  # Array
  defunpack [0b1001::4, len::4], do: unpack_list(len)
  defunpack [0xDC, len::16], do: unpack_list(len)
  defunpack [0xDD, len::32], do: unpack_list(len)

  # Map
  defunpack [0b1000::4, len::4], do: unpack_map(len)
  defunpack [0xDE, len::16], do: unpack_map(len)
  defunpack [0xDF, len::32], do: unpack_map(len)

  # Extension
  defunpack [0xD4, type, val::1-bytes], do: unpack_ext(type, val)
  defunpack [0xD5, type, val::2-bytes], do: unpack_ext(type, val)
  defunpack [0xD6, type, val::4-bytes], do: unpack_ext(type, val)
  defunpack [0xD7, type, val::8-bytes], do: unpack_ext(type, val)
  defunpack [0xD8, type, val::16-bytes], do: unpack_ext(type, val)

  defunpack [0xC7, len, type, val::size(len)-bytes], do: unpack_ext(type, val)
  defunpack [0xC8, len::16, type, val::size(len)-bytes], do: unpack_ext(type, val)
  defunpack [0xC9, len::32, type, val::size(len)-bytes], do: unpack_ext(type, val)

  def unpack(<<bin, _::bytes>>, _opts),
    do: throw({:bad_format, bin})

  def unpack(<<_::bits>>, _opts),
    do: throw(:incomplete)

  defp unpack_binary(rest, %{binary: true}, val),
    do: {Msgpax.Bin.new(val), rest}

  defp unpack_binary(rest, _opts, val),
    do: {val, rest}

  defp unpack_list(rest, opts, len, acc \\ [])
  defp unpack_list(rest, _opts, 0, acc),
    do: {Enum.reverse(acc), rest}

  defp unpack_list(rest, opts, len, acc) do
    {val, rest} = unpack(rest, opts)
    unpack_list(rest, opts, len - 1, [val | acc])
  end

  defp unpack_map(rest, opts, len, acc \\ [])
  defp unpack_map(rest, _opts, 0, acc),
    do: {Enum.into(Enum.reverse(acc), %{}), rest}

  defp unpack_map(rest, opts, len, acc) do
    {key, rest} = unpack(rest, opts)
    {val, rest} = unpack(rest, opts)
    unpack_map(rest, opts, len - 1, [{key, val} | acc])
  end

  defp unpack_ext(rest, opts, type, data) when type in 0..127 do
    {unpack_ext(type, data, opts), rest}
  end

  defp unpack_ext(_rest, _opts, type, _data) do
    throw {:not_supported_ext, type}
  end

  defp unpack_ext(type, data, %{ext: module}) when is_atom(module) do
    case module.unpack(Msgpax.Ext.new(type, data)) do
      {:ok, result} -> result
      :error ->
        throw {:ext_unpack_failure, type, module, data}
    end
  end

  defp unpack_ext(type, data, _opts) do
    Msgpax.Ext.new(type, data)
  end
end
