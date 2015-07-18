defmodule Msgpax.Bin do
  defstruct [:data]

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
