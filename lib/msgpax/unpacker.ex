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
    unpack_top_level(buffer, Map.new(options))
  end

  @primitives %{
    [quote(do: <<0xC0>>)] => quote(do: nil),
    [quote(do: <<0xC2>>)] => quote(do: false),
    [quote(do: <<0xC3>>)] => quote(do: true),
    [
      # Strings
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
    [quote(do: <<0b111::3, value::5>>)] => quote(do: value - 0b100000),
    # # Binaries
    [
      quote(do: <<0xC4, length::8, content::size(length)-bytes>>),
      quote(do: <<0xC5, length::16, content::size(length)-bytes>>),
      quote(do: <<0xC6, length::32, content::size(length)-bytes>>)
    ] => quote(do: unpack_binary(content, options)),
    # Extensions
    [
      quote(do: <<0xD4, type, content::1-bytes>>),
      quote(do: <<0xD5, type, content::2-bytes>>),
      quote(do: <<0xD6, type, content::4-bytes>>),
      quote(do: <<0xD7, type, content::8-bytes>>),
      quote(do: <<0xD8, type, content::16-bytes>>),
      quote(do: <<0xC7, length::8, type, content::size(length)-bytes>>),
      quote(do: <<0xC8, length::16, type, content::size(length)-bytes>>),
      quote(do: <<0xC9, length::32, type, content::size(length)-bytes>>)
    ] => quote(do: unpack_ext(type, content, options))
  }

  @collection_pats %{
    [
      quote(do: <<0b1001::4, list_size::4>>),
      quote(do: <<0xDC, list_size::16>>),
      quote(do: <<0xDD, list_size::32>>)
    ] => {:unpack_list, quote(do: list_size)},
    [
      quote(do: <<0b1000::4, map_size::4>>),
      quote(do: <<0xDE, map_size::16>>),
      quote(do: <<0xDF, map_size::32>>)
    ] => {:unpack_map, quote(do: map_size)}
  }

  # Top Level
  for {pats, value} <- @primitives do
    for pat <- pats do
      defp unpack_top_level(<<unquote(pat), rest::bits>>, unquote(quote(do: options))) do
        {unquote(value), rest}
      end
    end
  end

  for {pats, {unpack_collection, list_size}} <- @collection_pats do
    for pat <- pats do
      defp unpack_top_level(<<unquote(pat), rest::bits>>, options) do
        unquote(unpack_collection)(rest, unquote(list_size), [], options)
      end
    end
  end

  defp unpack_top_level(<<byte, _::bits>>, _options) do
    throw({:invalid_format, byte})
  end

  defp unpack_top_level(<<_::bits>>, _options) do
    throw(:incomplete)
  end

  # Parse List
  defp unpack_list(bin, 0, acc, _options) do
    {:lists.reverse(acc), bin}
  end

  for {pats, value} <- @primitives do
    for pat <- pats do
      defp unpack_list(<<unquote(pat), rest::bits>>, remaining, acc, unquote(quote(do: options))) do
        unpack_list(rest, remaining - 1, [unquote(value) | acc], unquote(quote(do: options)))
      end
    end
  end

  for {pats, {unpack_collection, size}} <- @collection_pats do
    for pat <- pats do
      defp unpack_list(<<unquote(pat), rest::bits>>, remaining, acc, options) do
        # Parse sublist
        {element, after_element} = unquote(unpack_collection)(rest, unquote(size), [], options)
        # Continue parsing current list
        unpack_list(after_element, remaining - 1, [element | acc], options)
      end
    end
  end

  defp unpack_list(<<byte, _::bits>>, _remaining, _acc, _options) do
    throw({:invalid_format, byte})
  end

  defp unpack_list(<<_::bits>>, _remaining, _acc, _options) do
    throw(:incomplete)
  end

  # Parse Map
  defp unpack_map(bin, 0, acc, _options) do
    {:maps.from_list(acc), bin}
  end

  for {pats, value} <- @primitives do
    for pat <- pats do
      defp unpack_map(<<unquote(pat), rest::bits>>, remaining, acc, unquote(quote(do: options))) do
        unpack_map_value(rest, remaining, acc, unquote(value), unquote(quote(do: options)))
      end
    end
  end

  for {pats, {unpack_collection, size}} <- @collection_pats do
    for pat <- pats do
      defp unpack_map(<<unquote(pat), rest::bits>>, remaining, acc, options) do
        # subcollection as key
        {key, after_element} = unquote(unpack_collection)(rest, unquote(size), [], options)
        unpack_map_value(after_element, remaining, acc, key, options)
      end
    end
  end

  defp unpack_map(<<byte, _::bits>>, _remaining, _acc, _options) do
    throw({:invalid_format, byte})
  end

  defp unpack_map(<<_::bits>>, _remaining, _acc, _options) do
    throw(:incomplete)
  end

  @compile {:inline, [unpack_map_value: 5]}

  # Parse Map value
  for {pats, value} <- @primitives do
    for pat <- pats do
      defp unpack_map_value(
             <<unquote(pat), rest::bits>>,
             remaining,
             acc,
             key,
             unquote(quote(do: options))
           ) do
        unpack_map(
          rest,
          remaining - 1,
          [{key, unquote(value)} | acc],
          unquote(quote(do: options))
        )
      end
    end
  end

  for {pats, {unpack_collection, size}} <- @collection_pats do
    for pat <- pats do
      defp unpack_map_value(<<unquote(pat), rest::bits>>, remaining, acc, key, options) do
        # Parse subcollection
        {element, after_element} = unquote(unpack_collection)(rest, unquote(size), [], options)
        # Continue parsing current map
        unpack_map(after_element, remaining - 1, [{key, element} | acc], options)
      end
    end
  end

  defp unpack_map_value(<<byte, _::bits>>, _remaining, _acc, _key, _options) do
    throw({:invalid_format, byte})
  end

  defp unpack_map_value(<<_::bits>>, _remaining, _acc, _key, _options) do
    throw(:incomplete)
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
end
