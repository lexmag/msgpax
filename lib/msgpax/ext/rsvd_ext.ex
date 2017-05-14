defmodule Msgpax.Ext.RsvdUnpacker do
  use Bitwise

  @behaviour Msgpax.Ext.Unpacker

  defimpl Msgpax.Packer, for: DateTime do
    @doc """
    Implemented following this guide
    https://github.com/msgpack/msgpack/pull/209
    FixExt4(-1) => seconds |  [1970-01-01 00:00:00 UTC, 2106-02-07 06:28:16 UTC) range
    FixExt8(-1) => nanoseconds + seconds | [1970-01-01 00:00:00.000000000 UTC, 2514-05-30 01:53:04.000000000 UTC) range
    Ext8(12,-1) => nanoseconds + seconds | [-584554047284-02-23 16:59:44 UTC, 584554051223-11-09 07:00:16.000000000 UTC) range

    Pseudo code for serialization:
    struct timespec {
        long tv_sec;  // seconds
        long tv_nsec; // nanoseconds
    } time;
    if ((time.tv_sec >> 34) == 0) {
        uint64_t data64 = (time.tv_nsec << 34) | time.tv_sec;
        if (data & 0xffffffff00000000L == 0) {
            // timestamp 32
            uint32_t data32 = data64;
            serialize(0xd6, -1, data32)
        }
        else {
            // timestamp 64
            serialize(0xd7, -1, data64)
        }
    }
    else {
        // timestamp 96
        serialize(0xc7, 12, -1, time.tv_nsec, time.tv_sec)
    }
    """
    def pack(value) do
      Msgpax.Ext.new(-1, get_bin(value))
      |> Msgpax.Packer.pack
    end

    defp get_bin(time) do
      seconds = @for.to_unix(time)
      nanoseconds = @for.to_unix(time, :nanosecond) - seconds * 1000000000

      if (seconds >>> 34) == 0 do
        data64 = nanoseconds <<< 34 ||| seconds
        if (data64 &&& 18446744069414584320) == 0 do
          <<seconds::32>>
        else
          <<data64::64>>
        end
      else
        <<nanoseconds::32>> <> <<seconds::64>>
      end
    end
  end


  @doc """
  Pseudo code for deserialization:
   ExtensionValue value = deserialize_ext_type();
   struct timespec result;
   switch(value.length) {
   case 4:
       uint32_t data32 = value.payload;
       result.tv_nsec = 0;
       result.tv_sec = data32;
   case 8:
       uint64_t data64 = value.payload;
       result.tv_nsec = data64 >> 34;
       result.tv_sec = data64 & 0x00000003ffffffffL;
   case 12:
       uint32_t data32 = value.payload;
       uint64_t data64 = value.payload + 4;
       result.tv_nsec = data32;
       result.tv_sec = data64;
   default:
       // error
   }
  """
  def unpack(%Msgpax.Ext{type: -1, data: data}) do
    case byte_size(data) do
      4 ->
        <<seconds::32>> = data
        DateTime.from_unix(seconds)
      8 ->
        <<data64::64>> = data
        nanoseconds = data64 >>> 34;
        seconds = data64 &&& 17179869183
        total_nanos = seconds * 1000000000 + nanoseconds
        DateTime.from_unix(total_nanos, :nanosecond)
      12 ->
        <<nanoseconds::32, seconds::64>> = data
        total_nanos = seconds * 1000000000 + nanoseconds
        #Erlang only support datetime max to #<DateTime(9999-12-31T23:59:59Z Etc/UTC)>
        #min to #<DateTime(0000-01-01T00:00:00Z Etc/UTC)> 
        total_nanos = 
        cond do
          total_nanos < -62167219200000000000 -> -62167219200000000000
          total_nanos > 253402300799999999999 -> 253402300799999999999
          true -> total_nanos
        end
        DateTime.from_unix(total_nanos, :nanosecond)
      _->
        :error
    end
  end
end
