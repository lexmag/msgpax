Code.require_file "../test_helper.exs", __FILE__

defmodule MessagePack.BitStringTest do
  use MessagePack.Case

  test "fixstring" do
    assert pack?("", <<160>>)
    assert pack?(String.duplicate("abcdef", 5) <> "z", <<191>>)
  end

  test "string 8" do
    assert pack?(String.duplicate("abcdef", 5) <> "zz", <<217, 32>>)
    assert pack?(String.duplicate("abcde", 51), <<217, 255>>)
  end

  test "string 16" do
    assert pack?(String.duplicate("abcde", 51) <> "z", <<218, 1, 0>>)
    assert pack?(String.duplicate("abcde", 13107), <<218, 255, 255>>)
  end

  test "string 32" do
    assert pack?(String.duplicate("abcde", 13107) <> "z", <<219, 0, 1, 0, 0>>)
  end

  test "bitsring" do
    assert_raise ArgumentError, "argument error", fn ->
      pack(<<1 :: 3>>)
    end
  end

  defp pack?(string, pattern) do
    pack(string) == iolist_to_binary([pattern, string])
  end
end

defmodule MessagePack.ListTest do
  use MessagePack.Case

  test "fixarray" do
    assert pack?([], <<144>>)
    assert pack?(List.duplicate(1, 15), <<159>>)
  end

  test "array 16" do
    assert pack?(List.duplicate(1, 16), <<220, 0, 16>>)
    assert pack?(List.duplicate(1, 65535), <<220, 255, 255>>)
  end

  test "array 32" do
    assert pack?(List.duplicate(1, 65536), <<221, 0, 1, 0, 0>>)
  end

  test "fixmap" do
    assert pack([{}]) == <<128>>
    assert pack?(List.duplicate({ 0, 1 }, 15), <<143>>)
  end

  test "map 16" do
    assert pack?(List.duplicate({ 0, 1 }, 16), <<222, 0, 16>>)
    assert pack?(List.duplicate({ 0, 1 }, 65535), <<222, 255, 255>>)
  end

  test "map 32" do
    assert pack?(List.duplicate({ 0, 1} , 65536), <<223, 0, 1, 0, 0>>)
  end

  defp pack?(list, pattern) do
    pack(list) == iolist_to_binary([pattern, flatten(list)])
  end

  defp flatten(list) do
    case list do
      [{_, _} | _] ->
        Enum.map list, fn({k, v}) -> [k, v] end

      _ -> list
    end
  end
end

defmodule MessagePack.AtomTest do
  use MessagePack.Case

  test "nil" do
    assert pack(nil) == <<192>>
  end

  test "false" do
    assert pack(false) == <<194>>
  end

  test "true" do
    assert pack(true) == <<195>>
  end
end

defmodule MessagePack.NumberTest do
  use MessagePack.Case

  test "float" do
    assert pack(42.0) == <<203, 64, 69, 0, 0, 0, 0, 0, 0>>
  end

  test "positive fixint" do
    assert pack(0) == <<0>>
    assert pack(127) == <<127>>
  end

  test "int 8" do
    assert pack(128) == <<204, 128>>
    assert pack(255) == <<204, 255>>
  end

  test "int 16" do
    assert pack(256) == <<205, 1, 0>>
    assert pack(65535) == <<205, 255, 255>>
  end

  test "int 32" do
    assert pack(65536) == <<206, 0, 1, 0, 0>>
    assert pack(4294967295) == <<206, 255, 255, 255, 255>>
  end

  test "int 64" do
    assert pack(4294967296) == <<207, 0, 0, 0, 1, 0, 0, 0, 0>>
  end

  test "negative fixint" do
    assert pack(-1) == <<255>>
    assert pack(-32) == <<224>>
  end

  test "uint 8" do
    assert pack(-33) == <<208, 223>>
    assert pack(-128) == <<208, 128>>
  end

  test "uint 16" do
    assert pack(-129) == <<209, 255, 127>>
    assert pack(-32768) == <<209, 128, 0>>
  end

  test "uint 32" do
    assert pack(-32769) == <<210, 255, 255, 127, 255>>
    assert pack(-2147483648) == <<210, 128, 0, 0, 0>>
  end

  test "uint 64" do
    assert pack(-2147483649) == <<211, 255, 255, 255, 255, 127, 255, 255, 255>>
  end
end
