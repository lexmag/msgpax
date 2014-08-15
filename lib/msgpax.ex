defmodule Msgpax do
  defdelegate [pack(term), pack!(term)], to: __MODULE__.Packer
  defdelegate [unpack(iodata), unpack!(iodata)], to: __MODULE__.Unpacker
end
