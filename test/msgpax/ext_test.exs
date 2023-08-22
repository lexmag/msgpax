defmodule Msgpax.ExtTest do
  use Msgpax.Case, async: true

  doctest Msgpax.Ext, except: [:moduledoc]

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
      def pack(%Sample{seed: seed, size: size}, options) do
        module = if is_list(seed), do: List, else: String

        42
        |> Msgpax.Ext.new(module.duplicate(seed, size))
        |> @protocol.Msgpax.Ext.pack(options)
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
    assert_format data, <<0xD4, 42, ?A>>, {data, [ext: Sample]}
  end

  test "fixext 2" do
    data = Sample.new("B", 2)
    assert_format data, <<0xD5, 42, ?B>>, {data, [ext: Sample]}
  end

  test "fixext 4" do
    data = Sample.new("C", 4)
    assert_format data, <<0xD6, 42, ?C>>, {data, [ext: Sample]}
  end

  test "fixext 8" do
    data = Sample.new("D", 8)
    assert_format data, <<0xD7, 42, ?D>>, {data, [ext: Sample]}
  end

  test "fixext 16" do
    data = Sample.new("E", 16)
    assert_format data, <<0xD8, 42, ?E>>, {data, [ext: Sample]}
  end

  test "ext 8" do
    input = Sample.new("0", 0)
    output = Sample.new("", 0)
    assert_format input, <<0xC7, 0, 42>>, {output, [ext: Sample]}
    data = Sample.new("1", 255)
    assert_format data, <<0xC7, 255, 42, ?1>>, {data, [ext: Sample]}
  end

  test "ext 16" do
    data = Sample.new("2", 0x100)
    assert_format data, <<0xC8, 0x100::16, 42, ?2>>, {data, [ext: Sample]}
    data = Sample.new("3", 0xFFFF)
    assert_format data, <<0xC8, 0xFFFF::16, 42, ?3>>, {data, [ext: Sample]}
  end

  test "ext 32" do
    data = Sample.new("4", 0x10000)
    assert_format data, <<0xC9, 0x10000::32, 42, ?4>>, {data, [ext: Sample]}
  end

  test "empty options" do
    output = Msgpax.Ext.new(42, "G")
    assert_format Sample.new("G", 1), <<0xD4, 42, ?G>>, output
  end

  test "iodata input" do
    output = Msgpax.Ext.new(42, "HH")
    assert_format Sample.new('H', 2), <<0xD5, 42, ?H>>, output
  end

  test "broken ext" do
    assert {:error, %UnpackError{reason: reason}} = Msgpax.unpack(<<0xD4, 42, ?A>>, ext: Broken)
    assert reason == {:ext_unpack_failure, Broken, Msgpax.Ext.new(42, "A")}
  end

  test "not supported reserved ext type" do
    assert {:ok, result} = Msgpax.unpack(<<0xD4, -5, ?A>>)
    assert result == %Msgpax.ReservedExt{data: "A", type: -5}
  end
end
