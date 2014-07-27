defmodule Msgpax do
  defdelegate pack(term), to: __MODULE__.Packer
  defdelegate unpack(bin), to: __MODULE__.Unpacker
end
