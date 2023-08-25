defimpl Msgpax.Packer, for: DateTime do
  import Bitwise

  def pack(datetime, options) do
    -1
    |> Msgpax.ReservedExt.new(build_data(datetime))
    |> @protocol.pack(options)
  end

  defp build_data(datetime) do
    total_nanoseconds = @for.to_unix(datetime, :nanosecond)
    seconds = Integer.floor_div(total_nanoseconds, 1_000_000_000)
    nanoseconds = Integer.mod(total_nanoseconds, 1_000_000_000)

    if seconds >>> 34 == 0 do
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

defimpl Msgpax.Unpacker, for: Msgpax.ReservedExt127 do
  @nanosecond_range -62_167_219_200_000_000_000..253_402_300_799_999_999_999

  def unpack(%{data: <<seconds::32>>}, _options), do: DateTime.from_unix(seconds)

  def unpack(%{data: <<nanoseconds::30, seconds::34>>}, _options) do
    total_nanoseconds = seconds * 1_000_000_000 + nanoseconds
    DateTime.from_unix(total_nanoseconds, :nanosecond)
  end

  def unpack(%{data: <<nanoseconds::32, seconds::64-signed>>}, _options) do
    total_nanoseconds = seconds * 1_000_000_000 + nanoseconds

    if total_nanoseconds in @nanosecond_range do
      DateTime.from_unix(total_nanoseconds, :nanosecond)
    else
      :error
    end
  end

  def unpack(_reserved_ext_1, _options), do: :error
end
