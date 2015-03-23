defmodule Msgpax.Ext do
  defstruct [:type, :data]

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
