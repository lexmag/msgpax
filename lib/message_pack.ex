defmodule MessagePack do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__), only: :macros
    end
  end

  defmacro to_msgpack(term) do
    quote do
      unquote(__MODULE__).Serializer.process(unquote(term))
    end
  end

  defmacro from_msgpack(bin) do
    quote do
      unquote(__MODULE__).Deserializer.process(unquote(bin))
    end
  end

  def pack(term), do: to_msgpack(term)

  def unpack(bin), do: from_msgpack(bin)
end
