defmodule Msgpax.ExtTest do
  use Msgpax.Case, async: true

  alias Msgpax.UnpackError

  defmodule Sample do
    defstruct [:seed, :size]

    def new(seed, size) do
      %__MODULE__{seed: seed, size: size}
    end

    @behaviour Msgpax.Ext.Unpacker

    def unpack(%Msgpax.Ext{type: 42, data: <<>>}) do
      {:ok, new(<<>>, 0)}
    end

    def unpack(%Msgpax.Ext{type: 42, data: <<char, _::bytes>> = data}) do
      {:ok, new(<<char>>, byte_size(data))}
    end

    defimpl Msgpax.Packer do
      def pack(%Sample{seed: seed, size: size}) do
        Msgpax.Ext.new(42, String.duplicate(seed, size))
        |> @protocol.Msgpax.Ext.pack()
      end
    end
  end

  defmodule Broken do
    def unpack(%Msgpax.Ext{}) do
      :error
    end
  end

  test "fixext 1" do
    data = Sample.new("A", 1)
    assert_format data, <<0xD4, 42, 65>>, {data, [ext: Sample]}
  end

  test "fixext 2" do
    data = Sample.new("B", 2)
    assert_format data, <<0xD5, 42, 66>>, {data, [ext: Sample]}
  end

  test "fixext 4" do
    data = Sample.new("C", 4)
    assert_format data, <<0xD6, 42, 67>>, {data, [ext: Sample]}
  end

  test "fixext 8" do
    data = Sample.new("D", 8)
    assert_format data, <<0xD7, 42, 68>>, {data, [ext: Sample]}
  end

  test "fixext 16" do
    data = Sample.new("E", 16)
    assert_format data, <<0xD8, 42, 69>>, {data, [ext: Sample]}
  end

  test "ext 8" do
    input = Sample.new("0", 0)
    output = Sample.new("", 0)
    assert_format input, <<0xC7, 0, 42>>, {output, [ext: Sample]}
    data = Sample.new("1", 255)
    assert_format data, <<0xC7, 255, 42, 49>>, {data, [ext: Sample]}
  end

  test "ext 16" do
    data = Sample.new("2", 0x100)
    assert_format data, <<0xC8, 0x100::16, 42, 50>>, {data, [ext: Sample]}
    data = Sample.new("3", 0xFFFF)
    assert_format data, <<0xC8, 0xFFFF::16, 42, 51>>, {data, [ext: Sample]}
  end

  test "ext 32" do
    data = Sample.new("4", 0x10000)
    assert_format data, <<0xC9, 0x10000::32, 42, 52>>, {data, [ext: Sample]}
  end

  test "empty options" do
    input = Sample.new("A", 1)
    output = Msgpax.Ext.new(42, "A")
    assert_format input, <<0xD4, 42, 65>>, output
  end

  test "broken ext" do
    assert {:error, %UnpackError{reason: reason}} = Msgpax.unpack(<<0xD4, 42, 65>>, ext: Broken)
    assert reason == {:ext_unpack_failure, Broken, Msgpax.Ext.new(42, "A")}
  end

  test "not supported reserved ext type" do
    assert {:ok, result} = Msgpax.unpack(<<0xD4, -5, 65>>)
    assert result == %Msgpax.ReservedExt{data: "A", type: -5}
  end
end
