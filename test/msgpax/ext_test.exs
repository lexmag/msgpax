defmodule Msgpax.ExtTest do
  use Msgpax.Case, async: true

  doctest Msgpax.Ext, except: [:moduledoc]

  alias Msgpax.UnpackError

  defmodule Sample do
    defstruct [:seed, :size]

    def new(seed, size) do
      %__MODULE__{seed: seed, size: size}
    end

    defimpl Msgpax.Packer do
      def pack(%Sample{seed: seed, size: size}, options) do
        module = if is_list(seed), do: List, else: String

        42
        |> Msgpax.Ext.new(module.duplicate(seed, size))
        |> @protocol.pack(options)
      end
    end

    defimpl Msgpax.Unpacker, for: Msgpax.Ext42 do
      def unpack(%{data: <<>>}, _options) do
        {:ok, Sample.new(<<>>, 0)}
      end

      def unpack(%{data: <<char, _::bytes>> = data}, options) do
        case Keyword.get(options, :break_me) do
          true -> :error
          _ -> {:ok, Sample.new(<<char>>, byte_size(data))}
        end
      end
    end
  end

  test "fixext 1" do
    data = Sample.new("A", 1)
    assert_format data, <<0xD4, 42, ?A>>, data
  end

  test "fixext 2" do
    data = Sample.new("B", 2)
    assert_format data, <<0xD5, 42, ?B>>, data
  end

  test "fixext 4" do
    data = Sample.new("C", 4)
    assert_format data, <<0xD6, 42, ?C>>, data
  end

  test "fixext 8" do
    data = Sample.new("D", 8)
    assert_format data, <<0xD7, 42, ?D>>, data
  end

  test "fixext 16" do
    data = Sample.new("E", 16)
    assert_format data, <<0xD8, 42, ?E>>, data
  end

  test "ext 8" do
    input = Sample.new("0", 0)
    output = Sample.new("", 0)
    assert_format input, <<0xC7, 0, 42>>, output
    data = Sample.new("1", 255)
    assert_format data, <<0xC7, 255, 42, ?1>>, data
  end

  test "ext 16" do
    data = Sample.new("2", 0x100)
    assert_format data, <<0xC8, 0x100::16, 42, ?2>>, data
    data = Sample.new("3", 0xFFFF)
    assert_format data, <<0xC8, 0xFFFF::16, 42, ?3>>, data
  end

  test "ext 32" do
    data = Sample.new("4", 0x10000)
    assert_format data, <<0xC9, 0x10000::32, 42, ?4>>, data
  end

  test "empty options" do
    data = Sample.new("G", 1)
    assert_format data, <<0xD4, 42, ?G>>, data
  end

  test "iodata input" do
    assert_format Sample.new('H', 2), <<0xD5, 42, ?H>>, Sample.new("H", 2)
  end

  test "broken ext unpacker" do
    assert {:error, unpack_error} = Msgpax.unpack(<<0xD4, 42, ?A>>, break_me: true)

    assert unpack_error == %UnpackError{
             reason: {:ext_unpack_failure, Msgpax.Ext42, %Msgpax.Ext42{data: "A"}}
           }
  end

  test "ext unpacker not implemented" do
    assert {:error, reason} = Msgpax.unpack(<<0xD4, 43, ?A>>)

    assert %Protocol.UndefinedError{protocol: Msgpax.Unpacker, value: %Msgpax.Ext43{data: "A"}} =
             reason
  end
end
