defmodule Msgpax.Ext do
  @moduledoc """
  A struct used to represent the MessagePack [Extension
  type](https://github.com/msgpack/msgpack/blob/master/spec.md#formats-ext).

  ## Examples

  Let's say we want to be able to serialize a custom type that consists of a
  byte `data` repeated `count` times. We could represent this as a `RepByte`
  struct in Elixir:

      defmodule RepByte do
        defstruct [:data, :count]
      end

  A simple (albeit not space efficient) approach to encoding such data is simply
  a binary containing `data` for `count` times: `%RepByte{data: ?a, count: 2}`
  would be encoded as `"aa"`.

  We can now define the `Msgpax.Packer` protocol for the `RepByte` struct to
  tell `Msgpax` how to encode this struct (we'll choose `10` as an arbitrary
  integer to identify the type of this extension).

      defimpl Msgpax.Packer, for: RepByte do
        @rep_byte_ext_type 10

        def pack(%RepByte{data: byte, count: count}) do
          @rep_byte_ext_type
          |> Msgpax.Ext.new(String.duplicate(<<byte>>, count))
          |> Msgpax.Packer.pack()
        end
      end

  Now, we can pack `RepByte`s:

      iex> packed = Msgpax.pack!(%RepByte{data: ?a, count: 3})
      iex> Msgpax.unpack!(packed)
      #Msgpax.Ext<10, "aaa">

  ### Unpacking

  As seen in the example above, since the `RepByte` struct is *packed* as a
  MessagePack extension, it will be unpacked as that extension later on; what we
  may want, however, is to unpack that extension back to a `RepByte` struct.

  To do this, we can pass an `:ext` option to `Msgpax.unpack/2` (and other
  unpacking functions). This option has to be a module that implements the
  `Msgpax.Ext.Unpacker` behaviour; it will be used to unpack extensions to
  arbitrary Elixir terms.

  For our `RepByte` example, we could create an unpacker module like this:

      defmodule MyExtUnpacker do
        @behaviour Msgpax.Ext.Unpacker
        @rep_byte_ext_type 10

        @impl true
        def unpack(%Msgpax.Ext{type: @rep_byte_ext_type, data: data}) do
          <<byte, _rest::binary>> = data
          {:ok, %RepByte{data: byte, count: byte_size(data)}}
        end
      end

  With this in place, we can now unpack a packed `RepByte` back to a `RepByte`
  struct:

      iex> packed = Msgpax.pack!(%RepByte{data: ?a, count: 3})
      iex> Msgpax.unpack!(packed, ext: MyExtUnpacker)
      %RepByte{data: ?a, count: 3}

  """

  @type type :: 0..127
  @type t :: %__MODULE__{type: type, data: iodata}

  defstruct [:type, :data]

  @doc """
  Creates a new `Msgpax.Ext` struct.

  `type` must be an integer in `0..127` and it will be used as the type of the
  extension (whose meaning depends on your application). `data` must be an iodata
  containing the serialized extension (whose serialization depends on your
  application).

  ## Examples

      iex> Msgpax.Ext.new(24, "foo")
      #Msgpax.Ext<24, "foo">

      iex> Msgpax.Ext.new(25, 'bar')
      #Msgpax.Ext<25, 'bar'>

  """
  def new(type, data)
      when type in 0..127 and (is_binary(data) or is_list(data)) do
    %__MODULE__{type: type, data: data}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{type: type, data: data}, opts) do
      concat([
        "#Msgpax.Ext<",
        Inspect.Integer.inspect(type, opts),
        ", ",
        to_doc(data, opts),
        ">"
      ])
    end
  end
end
