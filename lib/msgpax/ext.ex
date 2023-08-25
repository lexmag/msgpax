for type <- 0..127, s_type = Integer.to_string(type) do
  ext_module = Module.concat(Msgpax, "Ext#{type}")

  defmodule ext_module do
    @moduledoc false

    defstruct [:data]

    defimpl Msgpax.Packer, for: ext_module do
      def pack(%_{data: data}, options), do: Msgpax.Ext.__pack__(unquote(type), data, options)
    end

    defimpl Inspect do
      import Inspect.Algebra

      def inspect(%{data: data}, opts) do
        concat(["#Msgpax.Ext", unquote(s_type), "<", to_doc(data, opts), ">"])
      end
    end
  end
end

defmodule Msgpax.Ext do
  @moduledoc """
  A module used to create structs representing the MessagePack [Extension
  types](https://github.com/msgpack/msgpack/blob/master/spec.md#formats-ext).

  ## Examples

  Let's say we want to be able to serialize a custom type that consists of a
  byte `data` repeated `count` times. We could represent this as a `RepByte`
  struct in Elixir:

        defmodule RepByte do
          defstruct [:data, :count]
        end

  A straightforward (albeit not space-efficient) approach to encoding such data
  is by creating a binary containing `data` repeated for `count` times:
  `%RepByte{data: ?a, count: 2}` would be encoded as `"aa"`.

  We can now define the `Msgpax.Packer` protocol for the `RepByte` struct to
  inform `Msgpax` how to encode this struct (we'll use `10` as an arbitrary
  integer to identify the type of this extension).

        defimpl Msgpax.Packer, for: RepByte do
          @rep_byte_ext_type 10

          def pack(%RepByte{data: byte, count: count}, options) do
            @rep_byte_ext_type
            |> Msgpax.Ext.new(String.duplicate(<<byte>>, count))
            |> Msgpax.Packer.pack(options)
          end
        end

  Note that `Msgpax.Ext.new/2` returns the extension struct `Msgpax.Ext10`,
  which is then packed by `Msgpax.Packer` - all struct extensions already
  implement `Msgpax.Packer`.

  Now, we can pack `RepByte`s:

        iex> packed = Msgpax.pack!(%RepByte{data: ?a, count: 3})
        [[199, 3], 10 | "aaa"]

        iex> Msgpax.unpack!(packed)
        ** (Protocol.UndefinedError) protocol Msgpax.Unpacker not implemented for #Msgpax.Ext10<"aaa"> of type Msgpax.Ext10 (a struct).

  ### Unpacking

  Each extension type is mapped to a predetermined Elixir struct. For example,
  extension type `10` is mapped to `Msgpax.Ext10`. This struct contains the
  data field with the serialized extension data. There are 128 extensions ranging
  from 0 to 127.

  To unpack an extension back to a struct, we need to implement the
  `Msgpax.Unpacker` protocol for the extension struct. For our `RepByte` example,
  implementation might look like this:

        defimpl Msgpax.Unpacker, for: Msgpax.Ext10 do
          def unpack(%{data: <<byte, _rest::binary>>}, _options) do
            {:ok, %RepByte{data: byte, count: byte_size(data)}}
          end
        end

  With this in place, we can unpack a packed `RepByte`:

        iex> packed = Msgpax.pack!(%RepByte{data: ?a, count: 3})
        iex> Msgpax.unpack!(packed)
        %RepByte{data: ?a, count: 3}

  > #### `use Msgpax.Ext` {: .info}
  >
  > When you `use Msgpax.Ext`, the Msgpax.Ext module replaces the default
  > `Kernel.defimpl` with `Msgpax.Ext.defimpl`, allowing the overwriting of the
  > protocols defined by `Msgpax`.
  """

  @doc """
  Creates a new `Msgpax.Ext#` struct.

  `type` must be an integer in `0..127`, and it will be used as the type of the
  extension (whose meaning depends on your application). `data` must be an iodata
  containing the serialized extension (whose serialization depends on your
  application).

  ## Examples

      iex> Msgpax.Ext.new(24, "foo")
      #Msgpax.Ext24<"foo">

      iex> Msgpax.Ext.new(25, 'bar')
      #Msgpax.Ext25<'bar'>

  """
  for type <- 0..127 do
    extension = Module.concat(Msgpax, "Ext#{type}")

    def new(unquote(type), data) when is_binary(data) or is_list(data) do
      struct(unquote(extension), data: data)
    end
  end

  @doc false
  def __pack__(type, data, _options) do
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

  @doc """
  Works similarly to `Kernel.defimpl`, but it also allows overwriting
  default protocol implementations provided by `Msgpax`.

  Overriding one of the out-of-the-box types may be necessary if there are conflicts
  with your extensions or if a custom serialization format is required.

  Note that overwriting basic types such as `Atom` or `String` needs to be done
  through the use of an extension struct so that the proper unpacking
  implementation can be provided.

  ## Example

  You can overwrite the default implementation for `Date` as follows:

        use Msgpax.Ext # replaces Kernel.impl with Msgpax.Ext.defimpl

        defimpl Msgpax.Packer, for: Date do
          def pack(_date, options) do
            2
            |> Msgpax.Ext.new("A")
            |> @protocol.pack(options)
          end
        end

        defimpl Msgpax.Unpacker, for: Msgpax.Ext2 do
          def unpack(%{data: date}, _options) do
            {:ok, date}
          end
        end

  This would lead to:

        iex > Date.utc_now() |> Msgpax.pack!() |> Msgpax.unpack!()
        "A"

  """
  defmacro defimpl(protocol, opts, do_block \\ []) do
    protocol = Macro.expand(protocol, __CALLER__)

    if protocol not in [Msgpax.Packer, Msgpax.Unpacker] do
      arity = (do_block == [] && "2") || "3"

      raise ArgumentError,
            "`Msgpax.defimpl/#{arity}` is not supported for protocols other than `Msgpax.Packer` and `Msgpax.Unpacker`: got `#{Macro.inspect_atom(:literal, protocol)}`"
    end

    for_module =
      opts
      |> Keyword.get(:for, __CALLER__.module)
      |> Macro.expand(__CALLER__)

    do_block = Keyword.get(opts, :do, do_block)

    quote do
      current_ignore_module_conflict = Code.get_compiler_option(:ignore_module_conflict) || false

      Code.put_compiler_option(:ignore_module_conflict, true)

      impl =
        defimpl unquote(protocol), for: unquote(for_module) do
          unquote(do_block)
        end

      Code.put_compiler_option(:ignore_module_conflict, current_ignore_module_conflict)

      impl
    end
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [defimpl: 2, defimpl: 3]
      import unquote(__MODULE__), only: [defimpl: 2, defimpl: 3]
    end
  end
end
