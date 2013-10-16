defprotocol MessagePack.Serializer do
  @only [Atom, BitString, List, Number]

  def process(term)
end

defimpl MessagePack.Serializer, for: Atom do
  def process(nil),   do: <<192>>
  def process(false), do: <<194>>
  def process(true),  do: <<195>>
end

defimpl MessagePack.Serializer, for: BitString do
  def process(bin) when byte_size(bin) < 32 do
    <<0b101 :: 3, byte_size(bin) :: 5, bin :: binary>>
  end

  def process(bin) when byte_size(bin) < 256 do
    <<217, byte_size(bin) :: 8, bin :: binary>>
  end

  def process(bin) when byte_size(bin) < 65536 do
    <<218, byte_size(bin) :: [size(16), big, unsigned, integer], bin :: binary>>
  end

  def process(bin) do
    <<219, byte_size(bin) :: [size(32), big, unsigned, integer], bin :: binary>>
  end
end

defimpl MessagePack.Serializer, for: List do
  defmacrop unsigned(s) do
    quote do: [size(unquote(s)), big, unsigned, integer]
  end

  defmacrop to_msgpack(term) do
    quote do
      MessagePack.Serializer.process(unquote(term))
    end
  end

  def process([{_, _} | _] = list), do: as_map(list)
  def process([{}]), do: as_map([])

  def process(list) when length(list) < 16 do
    <<0b1001 :: 4, length(list) :: 4, array_elements(list) :: binary>>
  end

  def process(list) when length(list) < 65536 do
    <<220, length(list) :: unsigned(16), array_elements(list) :: binary>>
  end

  def process(list) do
    <<221, length(list) :: unsigned(32), array_elements(list) :: binary>>
  end

  defp array_elements(list) do
    bc elem inlist list, do: <<to_msgpack(elem) :: binary>>
  end

  defp as_map(list) when length(list) < 16 do
    <<0b1000 :: 4, length(list) :: 4, map_elements(list) :: binary>>
  end

  defp as_map(list) when length(list) < 65536 do
    <<222, length(list) :: unsigned(16), map_elements(list) :: binary>>
  end

  defp as_map(list) do
    <<223, length(list) :: unsigned(32), map_elements(list) :: binary>>
  end

  defp map_elements(list) do
    bc { key, value } inlist list do
      <<to_msgpack(key) :: binary, to_msgpack(value) :: binary>>
    end
  end
end

defimpl MessagePack.Serializer, for: Number do
  def process(num) when is_integer(num) and num < 0 do
    as_int(num)
  end

  def process(num) when is_integer(num) do
    as_uint(num)
  end

  def process(num) when is_float(num) do
    <<203, num :: [size(64), big, float]>>
  end

  defp as_int(num) when num >= -32 do
    <<0b111 :: 3, num :: 5>>
  end

  defp as_int(num) when num >= -128 do
    <<208, num>>
  end

  defp as_int(num) when num >= -32768 do
    <<209, num :: 16>>
  end

  defp as_int(num) when num >= -2147483648 do
    <<210, num :: 32>>
  end

  defp as_int(num), do: <<211, num :: 64>>

  defp as_uint(num) when num < 128 do
    <<0 :: 1, num :: 7>>
  end

  defp as_uint(num) when num < 256 do
    <<204, num>>
  end

  defp as_uint(num) when num < 65536 do
    <<205, num :: 16>>
  end

  defp as_uint(num) when num < 4294967296 do
    <<206, num :: 32>>
  end

  defp as_uint(num), do: <<207, num :: 64>>
end
