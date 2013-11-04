defprotocol MessagePack.Serializer do
  def process(term)
end

defimpl MessagePack.Serializer, for: Atom do
  def process(nil),   do: <<0xC0>>
  def process(false), do: <<0xC2>>
  def process(true),  do: <<0xC3>>
end

defimpl MessagePack.Serializer, for: BitString do
  def process(bin) when byte_size(bin) < 32 do
    <<0b101 :: 3, byte_size(bin) :: 5, bin :: binary>>
  end

  def process(bin) when byte_size(bin) < 256 do
    <<0xD9, byte_size(bin) :: 8, bin :: binary>>
  end

  def process(bin) when byte_size(bin) < 65536 do
    <<0xDA, byte_size(bin) :: [size(16), big, unsigned, integer], bin :: binary>>
  end

  def process(bin) do
    <<0xDB, byte_size(bin) :: [size(32), big, unsigned, integer], bin :: binary>>
  end
end

defimpl MessagePack.Serializer, for: List do
  import MessagePack, only: [to_msgpack: 1]

  defmacrop unsigned(s) do
    quote do: [size(unquote(s)), big, unsigned, integer]
  end

  def process([{_, _} | _] = list), do: as_map(list)
  def process([{}]),                do: as_map([])

  def process(list) when length(list) < 16 do
    <<0b1001 :: 4, length(list) :: 4, array_terms(list) :: binary>>
  end

  def process(list) when length(list) < 65536 do
    <<0xDC, length(list) :: unsigned(16), array_terms(list) :: binary>>
  end

  def process(list) do
    <<0xDD, length(list) :: unsigned(32), array_terms(list) :: binary>>
  end

  defp array_terms(list) do
    bc term inlist list, do: <<to_msgpack(term) :: binary>>
  end

  defp as_map(list) when length(list) < 16 do
    <<0b1000 :: 4, length(list) :: 4, map_terms(list) :: binary>>
  end

  defp as_map(list) when length(list) < 65536 do
    <<0xDE, length(list) :: unsigned(16), map_terms(list) :: binary>>
  end

  defp as_map(list) do
    <<0xDF, length(list) :: unsigned(32), map_terms(list) :: binary>>
  end

  defp map_terms(list) do
    bc { key, value } inlist list do
      <<to_msgpack(key) :: binary, to_msgpack(value) :: binary>>
    end
  end
end

defimpl MessagePack.Serializer, for: Float do
  def process(num) do
    <<0xCB, num :: [size(64), big, float]>>
  end
end

defimpl MessagePack.Serializer, for: Integer do
  def process(num) when num < 0 do
    as_int(num)
  end

  def process(num), do: as_uint(num)

  defp as_int(num) when num >= -32 do
    <<0b111 :: 3, num :: 5>>
  end

  defp as_int(num) when num >= -128 do
    <<0xD0, num>>
  end

  defp as_int(num) when num >= -32768 do
    <<0xD1, num :: 16>>
  end

  defp as_int(num) when num >= -2147483648 do
    <<0xD2, num :: 32>>
  end

  defp as_int(num), do: <<0xD3, num :: 64>>

  defp as_uint(num) when num < 128 do
    <<0 :: 1, num :: 7>>
  end

  defp as_uint(num) when num < 256 do
    <<0xCC, num>>
  end

  defp as_uint(num) when num < 65536 do
    <<0xCD, num :: 16>>
  end

  defp as_uint(num) when num < 4294967296 do
    <<0xCE, num :: 32>>
  end

  defp as_uint(num), do: <<0xCF, num :: 64>>
end
