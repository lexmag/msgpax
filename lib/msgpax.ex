defmodule Msgpax do
  defmodule Binary do
    defstruct [:data]
  end

  def binary(bin) when is_binary(bin) do
    %Binary{data: bin}
  end

  alias __MODULE__.Packer
  alias __MODULE__.Unpacker

  defdelegate [pack(term), pack!(term)], to: Packer

  def unpack(iodata, opts \\ %{}) do
    Unpacker.unpack(iodata, opts)
  end

  def unpack!(iodata, opts \\ %{}) do
    Unpacker.unpack!(iodata, opts)
  end
end
