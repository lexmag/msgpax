defprotocol MessagePack.Serlialization do
  @only [Atom, BitString, List, Number]
  
  def process(term)
end

defimpl MessagePack.Serlialization, for: Atom do
  def process(nil),   do: <<192>>
  def process(false), do: <<194>>
  def process(true),  do: <<195>>
end

defimpl MessagePack.Serlialization, for: BitString do
  def process(bin) when byte_size(bin) < 32 do
    <<101 :: 3, byte_size(bin) :: 5, bin :: binary>>
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

defimpl MessagePack.Serlialization, for: List do
  defmacrop unsigned(s) do
    quote do: [size(unquote(s)), big, unsigned, integer]
  end

  defmacrop to_msgpack(term) do
    quote do
      MessagePack.Serlialization.process(unquote(term))
    end
  end

  def process([{_, _} | _] = map), do: pack_map(map)
  def process([{}]), do: pack_map([])

  def process(l) when length(l) < 16 do
    <<0b1001 :: 4, length(l) :: 4, array_elements(l) :: binary>>
  end

  def process(l) when length(l) < 65536 do
    <<220, length(l) :: unsigned(16), array_elements(l) :: binary>>
  end

  def process(l) do
    <<221, length(l) :: unsigned(32), array_elements(l) :: binary>>
  end

  defp array_elements(array) do
    bc elem inlist array, do: <<to_msgpack(elem) :: binary>>
  end

  defp pack_map(m) when length(m) < 16 do
    <<0b1000 :: 4, length(m) :: 4, map_elements(m) :: binary>>
  end

  defp pack_map(m) when length(m) < 65536 do
    <<222, length(m) :: unsigned(16), map_elements(m) :: binary>>
  end

  defp pack_map(m) do
    <<223, length(m) :: unsigned(32), map_elements(m) :: binary>>
  end

  defp map_elements(map) do
    bc { key, value } inlist map do
      <<to_msgpack(key) :: binary, to_msgpack(value) :: binary>>
    end
  end
end

defimpl MessagePack.Serlialization, for: Number do
  def process(i) when is_integer(i) and i < 0 do
    pack_int(i)
  end

  def process(i) when is_integer(i) do
    pack_uint(i)
  end

  def process(f) when is_float(f) do
    <<203, f :: [size(64), big, float]>>
  end

  defp pack_int(int) when int >= -32 do
    <<111 :: 3, int :: 5>>
  end

  defp pack_int(int) when int >= -128 do
    <<208, int>>
  end

  defp pack_int(int) when int >= -32768 do
    <<209, int :: 16>>
  end

  defp pack_int(int) when int >= -2147483648 do
    <<210, int :: 32>>
  end

  defp pack_int(int), do: <<211, int :: 64>>

  defp pack_uint(int) when int < 128 do
    <<0 :: 1, int :: 7>>
  end

  defp pack_uint(int) when int < 256 do
    <<204, int>>
  end

  defp pack_uint(int) when int < 65536 do
    <<205, int :: 16>>
  end

  defp pack_uint(int) when int < 4294967296 do
    <<206, int :: 32>>
  end

  defp pack_uint(int), do: <<207, int :: 64>>
end
