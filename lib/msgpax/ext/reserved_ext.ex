defimpl Msgpax.Packer, for: DateTime do
  use Bitwise

  def pack(datetime) do
    Msgpax.ReservedExt.new(-1, build_data(datetime))
    |> @protocol.Msgpax.ReservedExt.pack()
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

defmodule Msgpax.ReservedExt do
  @moduledoc false

  @behaviour Msgpax.Ext.Unpacker

  @nanosecond_range -62_167_219_200_000_000_000..253_402_300_799_999_999_999

  @type type :: -128..-1
  @type t :: %__MODULE__{
          type: type,
          data: binary
        }

  defstruct [:type, :data]

  def new(type, data)
      when type in -128..-1 and is_binary(data) do
    %__MODULE__{type: type, data: data}
  end

  def unpack(%__MODULE__{type: -1, data: data}) do
    case data do
      <<seconds::32>> ->
        DateTime.from_unix(seconds)

      <<nanoseconds::30, seconds::34>> ->
        total_nanoseconds = seconds * 1_000_000_000 + nanoseconds
        DateTime.from_unix(total_nanoseconds, :nanosecond)

      <<nanoseconds::32, seconds::64-signed>> ->
        total_nanoseconds = seconds * 1_000_000_000 + nanoseconds

        if total_nanoseconds in @nanosecond_range do
          DateTime.from_unix(total_nanoseconds, :nanosecond)
        else
          :error
        end

      _ ->
        :error
    end
  end

  def unpack(%__MODULE__{} = struct) do
    {:ok, struct}
  end
end
