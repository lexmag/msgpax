defmodule Msgpax do
  defdelegate [pack(term), pack!(term)], to: __MODULE__.Packer
  defdelegate [unpack(bin), unpack!(bin)], to: __MODULE__.Unpacker
end
