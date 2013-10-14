defmodule MessagePack.Deserializer.DSL do
  defmacro defmatch(format, do: block) do
    def_match format, quote(do: rest |> unquote(block))
  end

  defmacro defmatch(format, as: value) do
    def_match format, quote(do: { unquote(value), rest })
  end

  defp def_match(format, body) do
    quote do
      defp match(<<unquote_splicing(format), rest :: binary>>) do
        unquote(body)
      end
    end
  end
end

defmodule MessagePack.Deserializer do
  defexception Error, message: "Invalid byte sequence"

  import MessagePack.Deserializer.DSL, only: :macros

  def process(bin) do
    case match(bin) do
      { value, <<>> } -> value
      { _, _rest } -> raise Error
    end
  end

  defmatch [0xC0], as: nil
  defmatch [0xC2], as: false
  defmatch [0xC3], as: true

  # String
  defmatch [0b101 :: 3, len :: 5, value :: [size(len), binary]],             as: value
  defmatch [0xD9, len :: integer, value :: [size(len), binary]],             as: value
  defmatch [0xDA, len :: [size(16), integer], value :: [size(len), binary]], as: value
  defmatch [0xDB, len :: [size(32), integer], value :: [size(len), binary]], as: value

  # Float
  defmatch [0xCA, value :: [size(32), big, float]], as: value
  defmatch [0xCB, value :: [size(64), big, float]], as: value

  # Integer
  defmatch [0 :: 1, value :: 7], as: value
  defmatch [0xCC, value ],       as: value
  defmatch [0xCD, value :: 16],  as: value
  defmatch [0xCE, value :: 32],  as: value
  defmatch [0xCF, value :: 64],  as: value

  defmatch [0b111 :: 3, value :: 5],                     as: value - 0b100000
  defmatch [0xD0, value :: [signed, integer]],           as: value
  defmatch [0xD1, value :: [size(16), signed, integer]], as: value
  defmatch [0xD2, value :: [size(32), signed, integer]], as: value
  defmatch [0xD3, value :: [size(64), signed, integer]], as: value

  # Array
  defmatch [0b1001 :: 4, len :: 4], do: as_array(len, [])
  defmatch [0xDC, len :: 16],       do: as_array(len, [])
  defmatch [0xDD, len :: 32],       do: as_array(len, [])

  # Map
  defmatch [0b1000 :: 4, len :: 4], do: as_map(len, [])
  defmatch [0xDE, len :: 16],       do: as_map(len, [])
  defmatch [0xDF, len :: 32],       do: as_map(len, [])

  defp match(_), do: raise Error

  defp as_array(rest, 0, acc) do
    { Enum.reverse(acc), rest }
  end

  defp as_array(rest, len, acc) do
    { value, rest } = match(rest)

    as_array(rest, len - 1, [value | acc])
  end

  defp as_map(rest, 0, []) do
    { [{}], rest }
  end

  defp as_map(rest, 0, acc) do
    { Enum.reverse(acc), rest }
  end

  defp as_map(rest, len, acc) do
    { key, rest } = match(rest)
    { value, rest } = match(rest)

    as_map(rest, len - 1, [{ key, value } | acc])
  end
end
