defmodule Msgpax.PackError do
  @moduledoc """
  Exception that represents an error in packing terms.

  This exception has a `:reason` field that can have one of the following
  values:

    * `{:not_encodable, term}` - means that the given argument is not
      serializable. For example, this is returned when you try to pack bits
      instead of a binary (as only binaries can be serialized).

    * `{:too_big, term}` - means that the given term is too big to be
      encoded. What "too big" means depends on the term being encoded; for
      example, integers larger than `18_446_744_073_709_551_616` are too big to be
      encoded with MessagePack.

  """

  @type t :: %__MODULE__{
          reason: {:too_big, any} | {:not_encodable, any}
        }

  defexception [:reason]

  def message(%__MODULE__{} = exception) do
    case exception.reason do
      {:too_big, term} ->
        "too big value: #{inspect(term)}"

      {:not_encodable, term} ->
        "not encodable value: #{inspect(term)}"
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
    * integers larger than `(2^64) - 1` or smaller than `-2^63` cannot be
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

  @doc """
  Returns serialized NaN in 64-bit format.
  """
  Kernel.def(pack_nan(), do: <<0xCB, -1::64>>)

  require Bitwise

  @doc """
  Returns serialized infinity in 64-bit format.
  """
  Kernel.def pack_infinity(:positive) do
    <<0xCB, 0::1, -1::11, 0::52>>
  end

  Kernel.def pack_infinity(:negative) do
    <<0xCB, -1::12, 0::52>>
  end
end

defimpl Msgpax.Packer, for: Atom do
  def pack(nil), do: [0xC0]
  def pack(false), do: [0xC2]
  def pack(true), do: [0xC3]

  def pack(atom) do
    atom
    |> Atom.to_string()
    |> @protocol.BitString.pack()
  end
end

defimpl Msgpax.Packer, for: BitString do
  def pack(binary) when is_binary(binary) do
    [format(binary) | binary]
  end

  def pack(bits) do
    throw({:not_encodable, bits})
  end

  defp format(binary) do
    size = byte_size(binary)

    cond do
      size < 32 -> 0b10100000 + size
      size < 256 -> [0xD9, size]
      size < 0x10000 -> <<0xDA, size::16>>
      size < 0x100000000 -> <<0xDB, size::32>>
      true -> throw({:too_big, binary})
    end
  end
end

defimpl Msgpax.Packer, for: Map do
  defmacro __deriving__(module, struct, options) do
    @protocol.Any.deriving(module, struct, options)
  end

  def pack(map) do
    [format(map) | map |> Map.to_list() |> pack([])]
  end

  defp pack([{key, value} | rest], result) do
    pack(rest, [@protocol.pack(key), @protocol.pack(value) | result])
  end

  defp pack([], result), do: result

  defp format(map) do
    length = map_size(map)

    cond do
      length < 16 -> 0b10000000 + length
      length < 0x10000 -> <<0xDE, length::16>>
      length < 0x100000000 -> <<0xDF, length::32>>
      true -> throw({:too_big, map})
    end
  end
end

defimpl Msgpax.Packer, for: List do
  def pack(list) do
    [format(list) | list |> Enum.reverse() |> pack([])]
  end

  defp pack([item | rest], result) do
    pack(rest, [@protocol.pack(item) | result])
  end

  defp pack([], result), do: result

  defp format(list) do
    length = length(list)

    cond do
      length < 16 -> 0b10010000 + length
      length < 0x10000 -> <<0xDC, length::16>>
      length < 0x100000000 -> <<0xDD, length::32>>
      true -> throw({:too_big, list})
    end
  end
end

defimpl Msgpax.Packer, for: Float do
  def pack(num) do
    <<0xCB, num::64-float>>
  end
end

defimpl Msgpax.Packer, for: Integer do
  def pack(int) when int < 0 do
    cond do
      int >= -32 -> [0x100 + int]
      int >= -128 -> [0xD0, 0x100 + int]
      int >= -0x8000 -> <<0xD1, int::16>>
      int >= -0x80000000 -> <<0xD2, int::32>>
      int >= -0x8000000000000000 -> <<0xD3, int::64>>
      true -> throw({:too_big, int})
    end
  end

  def pack(int) do
    cond do
      int < 128 -> [int]
      int < 256 -> [0xCC, int]
      int < 0x10000 -> <<0xCD, int::16>>
      int < 0x100000000 -> <<0xCE, int::32>>
      int < 0x10000000000000000 -> <<0xCF, int::64>>
      true -> throw({:too_big, int})
    end
  end
end

defimpl Msgpax.Packer, for: Msgpax.Bin do
  def pack(%{data: data}) when is_binary(data), do: [format(data) | data]

  defp format(binary) do
    size = byte_size(binary)

    cond do
      size < 256 -> [0xC4, size]
      size < 0x10000 -> <<0xC5, size::16>>
      size < 0x100000000 -> <<0xC6, size::32>>
      true -> throw({:too_big, binary})
    end
  end
end

defimpl Msgpax.Packer, for: [Msgpax.Ext, Msgpax.ReservedExt] do
  require Bitwise

  def pack(%_{type: type, data: data}) do
    [format(data), Bitwise.band(256 + type, 255) | data]
  end

  defp format(data) do
    size = IO.iodata_length(data)

    cond do
      size == 1 -> 0xD4
      size == 2 -> 0xD5
      size == 4 -> 0xD6
      size == 8 -> 0xD7
      size == 16 -> 0xD8
      size < 256 -> [0xC7, size]
      size < 0x10000 -> <<0xC8, size::16>>
      size < 0x100000000 -> <<0xC9, size::32>>
      true -> throw({:too_big, data})
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
          |> @protocol.Map.pack()
        end
      end
    end
  end

  def pack(term) do
    raise Protocol.UndefinedError, protocol: @protocol, value: term
  end
end
