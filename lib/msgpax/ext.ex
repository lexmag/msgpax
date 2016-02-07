defmodule Msgpax.Ext do
  @moduledoc """
  A struct used to represent a [MessagePack
  extension](https://github.com/msgpack/msgpack/blob/master/spec.md#formats-ext).

  ## Examples

  Let's say we want to be able to serialize a custom type that consists of a
  byte `b` repeated `reps` times. We could represent this as a `RepByte` struct
  in Elixir:

      defmodule RepByte do
        defstruct [:b, :reps]
      end

  A simple (albeit not space efficient) approach to encoding such data is simply
  a binary containing `b` for `reps` times: `%RepByte{str: ?a, reps: 2}` would be
  encoded as `"aa"`.

  We can now define the `Msgpax.Packer` protocol for the `RepByte` struct to
  tell `Msgpax` how to encode this struct (we'll choose `10` as an arbitrary
  integer to identify the type of this extension).

      defimpl Msgpax.Packer, for: RepByte do
        def transform(%RepByte{b: b, reps: reps}) do
          Msgpax.Ext.new(10, String.duplicate(<<b>>, reps))
          |> Msgpax.Packer.transform()
        end
      end

  Now, we can pack `RepByte`s:

      iex> packed = Msgpax.pack!(%RepByte{b: ?a, reps: 3})
      iex> Msgpax.unpack!(packed)
      #Msgpax.Ext<10, "aaa">

  """

  defstruct [:type, :data]

  @doc """
  Creates a new `Msgpax.Ext` struct.

  `type` must be an integer in `0..127` and it will be used as the type of the
  extension (whose meaning depends on your application). `data` must be a binary
  containing the serialized extension (whose serialization depends on your
  application).

  ## Examples

      iex> Msgpax.Ext.new(24, "foo")
      #Msgpax.Ext<24, "foo">

  """
  def new(type, data)
      when type in 0..127 and is_binary(data) do
    %__MODULE__{type: type, data: data}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{type: type, data: data}, opts) do
      concat ["#Msgpax.Ext<",
        Inspect.Integer.inspect(type, opts), ", ",
        Inspect.BitString.inspect(data, opts), ">"]
    end
  end
end
