defmodule Msgpax.Unpacker.Transform do
  defmacro transform(format, expr) do
    quote do
      defp transform(<<unquote_splicing(format), rest::bytes>>) do
        unquote(body_for(expr))
      end
    end
  end

  defp body_for(do: block) do
    quote do
      rest |> unquote(block)
    end
  end

  defp body_for(to: value) do
    quote do
      {unquote(value), rest}
    end
  end
end

defmodule Msgpax.UnpackError do
  defexception [:message]

  def exception({:extra_bytes, bin}) do
    %__MODULE__{message: "extra bytes follow after packet: #{inspect(bin)}"}
  end

  def exception({:invalid_format, bin}) do
    %__MODULE__{message: "invalid format: #{inspect(bin)}"}
  end

  def exception(:incomplete) do
    %__MODULE__{message: "packet is incomplete"}
  end
end

defmodule Msgpax.Unpacker do
  import __MODULE__.Transform

  def unpack(iodata) do
    bin = IO.iodata_to_binary(iodata)
    case transform(bin) do
      {value, <<>>} ->
        {:ok, value}
      {_, bytes} ->
        {:error, {:extra_bytes, bytes}}
    end
  catch
    :throw, reason ->
      {:error, reason}
  end

  def unpack!(bin) do
    case unpack(bin) do
      {:ok, value} -> value
      {:error, reason} ->
        raise Msgpax.UnpackError, reason
    end
  end

  transform [0xC0], to: nil
  transform [0xC2], to: false
  transform [0xC3], to: true

  # String
  transform [0b101::3, len::5, value::size(len)-bytes],      to: value
  transform [0xD9, len::integer, value::size(len)-bytes],    to: value
  transform [0xDA, len::16-integer, value::size(len)-bytes], to: value
  transform [0xDB, len::32-integer, value::size(len)-bytes], to: value

  # Float
  transform [0xCA, value::32-big-float], to: value
  transform [0xCB, value::64-big-float], to: value

  # Integer
  transform [0::1, value::7],  to: value
  transform [0xCC, value],     to: value
  transform [0xCD, value::16], to: value
  transform [0xCE, value::32], to: value
  transform [0xCF, value::64], to: value

  transform [0b111::3, value::5],             to: value - 0b100000
  transform [0xD0, value::signed-integer],    to: value
  transform [0xD1, value::16-signed-integer], to: value
  transform [0xD2, value::32-signed-integer], to: value
  transform [0xD3, value::64-signed-integer], to: value

  # Array
  transform [0b1001::4, len::4], do: list(len)
  transform [0xDC, len::16],     do: list(len)
  transform [0xDD, len::32],     do: list(len)

  # Map
  transform [0b1000::4, len::4], do: map(len)
  transform [0xDE, len::16],     do: map(len)
  transform [0xDF, len::32],     do: map(len)

  defp transform(<<bin, _::bytes>>),
    do: throw({:invalid_format, bin})

  defp transform(<<>>), do: throw(:incomplete)

  defp list(rest, len, acc \\ [])
  defp list(rest, 0, acc),
    do: {Enum.reverse(acc), rest}

  defp list(rest, len, acc) do
    {value, rest} = transform(rest)

    list(rest, len - 1, [value | acc])
  end

  defp map(rest, len, acc \\ [])
  defp map(rest, 0, acc),
    do: {Enum.into(Enum.reverse(acc), %{}), rest}

  defp map(rest, len, acc) do
    {key, rest} = transform(rest)
    {value, rest} = transform(rest)

    map(rest, len - 1, [{key, value} | acc])
  end
end
