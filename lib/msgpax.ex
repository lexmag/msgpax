defmodule Msgpax do
  defmodule Binary do
    defstruct [:data]
  end

  def binary(bin) when is_binary(bin) do
    %__MODULE__.Binary{data: bin}
  end

  defdelegate [pack(term), pack!(term)], to: __MODULE__.Packer
  defdelegate [unpack(iodata), unpack!(iodata)], to: __MODULE__.Unpacker
end
