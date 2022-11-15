defmodule Msgpax.Fragment do
  @moduledoc """
  Represents a fragment of MessagePack data.
  """

  @opaque t() :: %__MODULE__{data: iodata}

  defstruct [:data]

  @doc """
  Builds a `Msgpax.Fragment` from the given `packed_data`.

  ## Examples

      iex> Msgpax.Fragment.new(<<192>>)
      #Msgpax.Fragment<<<192>>>

  """
  @spec new(iodata) :: t()
  def new(packed_data) when is_binary(packed_data) or is_list(packed_data) do
    %__MODULE__{data: packed_data}
  end

  defimpl Msgpax.Packer do
    def pack(%{data: data}), do: data
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%{data: data}, options) do
      concat(["#Msgpax.Fragment<", to_doc(data, options), ">"])
    end
  end
end
