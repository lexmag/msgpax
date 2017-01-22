defmodule Msgpax.PackError do
  @moduledoc """
  Raised when there's an error in serializing an Elixir term.
  """

  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason do
      {:too_big, term} ->
        "value is too big: #{inspect(term)}"
      {:not_encodable, term} ->
        "value is not encodable: #{inspect(term)}"
    end
  end
end

defprotocol Msgpax.Packer do
  @moduledoc """
  The `Msgpax.Packer` protocol is responsible for serializing any Elixir data
  structure according to the MessagePack specification.

  Some notable properties of the implementation of this protocol for the
  built-in Elixir data structures:

    * atoms are encoded as strings (i.e., they're converted to strings first and
      then encoded as strings)
    * bitstrings can only be encoded as long as they're binaries (and not actual
      bitstrings - i.e., the number of bits must be a multiple of 8)
    * binaries (or `Msgpax.Bin` structs) containing `2^32` or more bytes cannot
      be encoded
    * maps with more than `(2^32) - 1` elements cannot be encoded
    * lists with more than `(2^32) - 1` elements cannot be encoded
    * integers bigger than `(2^64) - 1` or smaller than `-2^63` cannot be
      encoded

  ## Serializing a subset of fields for structs

  The `Msgpax.Packer` protocol supports serialization of only a subset of the
  fields of a struct when derived. For example:

      defmodule User do
        @derive [{Msgpax.Packer, fields: [:name]}]
        defstruct [:name, :sensitive_data]
      end

  In the example, packing `User` will only serialize the `:name` field and leave
  out the `:sensitive_data` field. By default, the `:__struct__` field is taken
  out of the struct before packing it. If you want this field to be present in
  the packed map, you have to set the `:include_struct_field` option to `true`.

  ## Unpacking back to Elixir structs

  When packing a struct, that struct will be packed as the underlying map and
  will be unpacked with string keys instead of atom keys. This makes it hard to
  reconstruct the map as tools like `Kernel.struct/2` can't be used (given keys
  are strings). Also, unless specifically stated with the `:include_struct_field`
  option, the `:__struct__` field is lost when packing a struct, so information
  about *which* struct it was is lost.

      %User{name: "Juri"} |> Msgpax.pack!() |> Msgpax.unpack!()
      #=> %{"name" => "Juri"}

  These things can be overcome by using something like
  [Maptu](https://github.com/lexhide/maptu), which helps to reconstruct
  structs:

      map = %User{name: "Juri"} |> Msgpax.pack!() |> Msgpax.unpack!()
      Maptu.struct!(User, map)
      #=> %User{name: "Juri"}

      map =
        %{"__struct__" => "Elixir.User", "name" => "Juri"}
        |> Msgpax.pack!()
        |> Msgpax.unpack!()

      Maptu.struct!(map)
      #=> %User{name: "Juri"}

  """

  @doc """
  This function serializes `term`.

  It returns an iodata result.
  """
  def pack(term)
end

defimpl Msgpax.Packer, for: Atom do
  def pack(nil),   do: <<0xC0>>
  def pack(false), do: <<0xC2>>
  def pack(true),  do: <<0xC3>>
  def pack(atom) do
    Atom.to_string(atom)
    |> @protocol.pack
  end
end

defimpl Msgpax.Packer, for: BitString do
  def pack(bin) when is_binary(bin) do
    [format(bin) | bin]
  end

  def pack(bits) do
    throw {:not_encodable, bits}
  end

  defp format(bin) do
    size = byte_size(bin)
    cond do
      size < 32          -> <<0b101::3, size::5>>
      size < 256         -> <<0xD9, size::8>>
      size < 0x10000     -> <<0xDA, size::16>>
      size < 0x100000000 -> <<0xDB, size::32>>

      true -> throw {:too_big, bin}
    end
  end
end

defimpl Msgpax.Packer, for: Map do
  defmacro __deriving__(module, struct, options) do
    @protocol.Any.deriving(module, struct, options)
  end

  def pack(map) do
    for {key, value} <- map, into: [format(map)] do
      [@protocol.pack(key) | @protocol.pack(value)]
    end
  end

  defp format(map) do
    len = Enum.count(map)
    cond do
      len < 16          -> <<0b1000::4, len::4>>
      len < 0x10000     -> <<0xDE, len::16>>
      len < 0x100000000 -> <<0xDF, len::32>>

      true -> throw {:too_big, map}
    end
  end
end

defimpl Msgpax.Packer, for: List do
  def pack([{}]), do: <<128>>
  def pack([{_, _} | _] = list),
    do: @protocol.Map.pack(list)

  def pack(list) do
    for elem <- list, into: [format(list)] do
      @protocol.pack(elem)
    end
  end

  defp format(list) do
    len = length(list)
    cond do
      len < 16          -> <<0b1001::4, len::4>>
      len < 0x10000     -> <<0xDC, len::16>>
      len < 0x100000000 -> <<0xDD, len::32>>

      true -> throw {:too_big, list}
    end
  end
end

defimpl Msgpax.Packer, for: Float do
  def pack(num) do
    <<0xCB, num::64-float>>
  end
end

defimpl Msgpax.Packer, for: Integer do
  def pack(num) when num < 0 do
    cond do
      num >= -32                 -> <<0b111::3, num::5>>
      num >= -128                -> <<0xD0, num>>
      num >= -0x8000             -> <<0xD1, num::16>>
      num >= -0x80000000         -> <<0xD2, num::32>>
      num >= -0x8000000000000000 -> <<0xD3, num::64>>

      true -> throw {:too_big, num}
    end
  end

  def pack(num) do
    cond do
      num < 128                 -> <<0::1, num::7>>
      num < 256                 -> <<0xCC, num>>
      num < 0x10000             -> <<0xCD, num::16>>
      num < 0x100000000         -> <<0xCE, num::32>>
      num < 0x10000000000000000 -> <<0xCF, num::64>>

      true -> throw {:too_big, num}
    end
  end
end

defimpl Msgpax.Packer, for: Msgpax.Bin do
  def pack(%{data: bin}) when is_binary(bin),
    do: [format(bin) | bin]

  defp format(bin) do
    size = byte_size(bin)
    cond do
      size < 256         -> <<0xC4, size::8>>
      size < 0x10000     -> <<0xC5, size::16>>
      size < 0x100000000 -> <<0xC6, size::32>>

      true -> throw {:too_big, bin}
    end
  end
end

defimpl Msgpax.Packer, for: Msgpax.Ext do
  def pack(%{type: type, data: data}) do
    [format(data), type | data]
  end

  defp format(data) do
    size = byte_size(data)
    cond do
      size == 1          -> <<0xD4>>
      size == 2          -> <<0xD5>>
      size == 4          -> <<0xD6>>
      size == 8          -> <<0xD7>>
      size == 16         -> <<0xD8>>
      size < 256         -> <<0xC7, size>>
      size < 0x10000     -> <<0xC8, size::16>>
      size < 0x100000000 -> <<0xC9, size::32>>

      true -> throw {:too_big, data}
    end
  end
end

defimpl Msgpax.Packer, for: Any do
  defmacro __deriving__(module, struct, options) do
    deriving(module, struct, options)
  end

  def deriving(module, struct, options) do
    keys = struct |> Map.from_struct() |> Map.keys()
    fields = Keyword.get(options, :fields, keys)
    include_struct_field? = Keyword.get(options, :include_struct_field, :__struct__ in fields)
    fields = List.delete(fields, :__struct__)
    extractor =
      cond do
        fields == keys and include_struct_field? ->
          quote(do: Map.from_struct(struct) |> Map.put("__struct__", unquote(module)))
        fields == keys ->
          quote(do: Map.from_struct(struct))
        include_struct_field? ->
          quote(do: Map.take(struct, unquote(fields)) |> Map.put("__struct__", unquote(module)))
        true ->
          quote(do: Map.take(struct, unquote(fields)))
      end

    quote do
      defimpl unquote(@protocol), for: unquote(module) do
        def pack(struct) do
          unquote(extractor)
          |> @protocol.Map.pack
        end
      end
    end
  end

  def pack(term) do
    raise Protocol.UndefinedError,
      protocol: @protocol, value: term
  end
end
