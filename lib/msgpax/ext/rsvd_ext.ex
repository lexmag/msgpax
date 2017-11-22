defimpl Msgpax.Packer, for: DateTime do
  use Bitwise

  def pack(datetime) do
    Msgpax.Ext.new(-1, build_data(datetime))
    |> @protocol.Msgpax.Ext.pack()
  end

  defp build_data(datetime) do
    total_nanoseconds = @for.to_unix(datetime, :nanosecond)
    seconds = Integer.floor_div(total_nanoseconds, 1_000_000_000)
    nanoseconds = Integer.mod(total_nanoseconds, 1_000_000_000)

    if (seconds >>> 34) == 0 do
      content = nanoseconds <<< 34 ||| seconds
      if (content &&& 0xFFFFFFFF00000000) == 0 do
        <<content::32>>
      else
        <<content::64>>
      end
    else
      <<nanoseconds::32, seconds::64>>
    end
  end
end

defmodule Msgpax.Ext.RsvdUnpacker do
  @behaviour Msgpax.Ext.Unpacker

  @min_nanoseconds -62_167_219_200_000_000_000
  @max_nanoseconds 253_402_300_799_999_999_999

  def unpack(%Msgpax.Ext{type: -1, data: data}) do
    case data do
      <<seconds::32>> ->
        DateTime.from_unix(seconds)
      <<nanoseconds::30, seconds::34>> ->
        total_nanoseconds = seconds * 1_000_000_000 + nanoseconds
        DateTime.from_unix(total_nanoseconds, :nanosecond)
      <<nanoseconds::32, seconds::64-signed>> ->
        total_nanoseconds = (seconds * 1_000_000_000 + nanoseconds)
        if total_nanoseconds in @min_nanoseconds..@max_nanoseconds do
          DateTime.from_unix(total_nanoseconds, :nanosecond)
        else
          :error
        end
      _ ->
        :error
    end
  end

  def unpack(%Msgpax.Ext{type: type, data: _}) do
    throw({:not_supported_reserved_ext, type})
  end
end
