defmodule Msgpax.Bin do
  @moduledoc """
  A struct to represent the MessagePack [Binary
  type](https://github.com/msgpack/msgpack/blob/master/spec.md#formats-bin).

  Elixir binaries are serialized and de-serialized as [MessagePack
  strings](https://github.com/msgpack/msgpack/blob/master/spec.md#formats-str):
  `Msgpax.Bin` is used when you want to enforce the serialization of a binary
  into the Binary MessagePack type. De-serialization functions (such as
  `Msgpax.unpack/2`) provide an option to deserialize Binary terms (which are
  de-serialized to Elixir binaries by default) to `Msgpax.Bin` structs.
  """

  @type t :: %__MODULE__{
    data: binary,
  }

  defstruct [:data]

  @doc """
  Creates a new `Msgpax.Bin` struct from the given binary.

  ## Examples

      iex> Msgpax.Bin.new("foo")
      #Msgpax.Bin<"foo">

  """
  def new(data) when is_binary(data) do
    %__MODULE__{data: data}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{data: data}, opts) do
      concat ["#Msgpax.Bin<", Inspect.BitString.inspect(data, opts), ">"]
    end
  end
end
