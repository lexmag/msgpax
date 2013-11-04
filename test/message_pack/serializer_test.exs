Code.require_file "../test_helper.exs", __DIR__

defmodule MessagePack.SerializerSuite do
  defmodule BitStringTest do
    use MessagePack.Case

    defmacrop assert_pack(string, prefix) do
      quote do
        assert pack(unquote(string)) == <<unquote_splicing(prefix), unquote(string) :: binary>>
      end
    end

    test "fixstring" do
      assert pack("") == <<160>>
      assert_pack string(31), [191]
    end

    test "string 8" do
      assert_pack string(32), [217, 32]
      assert_pack string(255), [217, 255]
    end

    test "string 16" do
      assert_pack string(256), [218, 1, 0]
      assert_pack string(65535), [218, 255, 255]
    end

    test "string 32" do
      assert_pack string(65536), [219, 0, 1, 0, 0]
    end

    test "bitsring" do
      assert_raise ArgumentError, "argument error", fn ->
        pack(<<7 :: 3>>)
      end
    end
  end

  defmodule ListTest do
    use MessagePack.Case

    defmacrop assert_pack(list, prefix) do
      quote do
        assert pack(unquote(list)) == <<unquote_splicing(prefix), do_pack(unquote(list)) :: binary>>
      end
    end

    defp do_pack([{_, _} | _] = list) do
      bc { key, value } inlist list do
        <<pack(key) :: binary, pack(value) :: binary>>
      end
    end

    defp do_pack(list) do
      bc elem inlist list, do: <<pack(elem) :: binary>>
    end

    test "fixarray" do
      assert pack([]) == <<144>>
      assert_pack array(15), [159]
    end

    test "array 16" do
      assert_pack array(16), [220, 0, 16]
      assert_pack array(65535), [220, 255, 255]
    end

    test "array 32" do
      assert_pack array(65536), [221, 0, 1, 0, 0]
    end

    test "fixmap" do
      assert pack([{}]) == <<128>>
      assert_pack map(15), [143]
    end

    test "map 16" do
      assert_pack map(16), [222, 0, 16]
      assert_pack map(65535), [222, 255, 255]
    end

    test "map 32" do
      assert_pack map(65536), [223, 0, 1, 0, 0]
    end
  end

  defmodule AtomTest do
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

  defmodule FloatTest do
    use MessagePack.Case

    test "float" do
      assert pack(42.1) == <<203, 64, 69, 12, 204, 204, 204, 204, 205>>
    end
  end

  defmodule IntegerTest do
    use MessagePack.Case

    test "positive fixint" do
      assert pack(0) == <<0>>
      assert pack(127) == <<127>>
    end

    test "uint 8" do
      assert pack(128) == <<204, 128>>
      assert pack(255) == <<204, 255>>
    end

    test "uint 16" do
      assert pack(256) == <<205, 1, 0>>
      assert pack(65535) == <<205, 255, 255>>
    end

    test "uint 32" do
      assert pack(65536) == <<206, 0, 1, 0, 0>>
      assert pack(4294967295) == <<206, 255, 255, 255, 255>>
    end

    test "uint 64" do
      assert pack(4294967296) == <<207, 0, 0, 0, 1, 0, 0, 0, 0>>
    end

    test "negative fixint" do
      assert pack(-1) == <<255>>
      assert pack(-32) == <<224>>
    end

    test "int 8" do
      assert pack(-33) == <<208, 223>>
      assert pack(-128) == <<208, 128>>
    end

    test "int 16" do
      assert pack(-129) == <<209, 255, 127>>
      assert pack(-32768) == <<209, 128, 0>>
    end

    test "int 32" do
      assert pack(-32769) == <<210, 255, 255, 127, 255>>
      assert pack(-2147483648) == <<210, 128, 0, 0, 0>>
    end

    test "int 64" do
      assert pack(-2147483649) == <<211, 255, 255, 255, 255, 127, 255, 255, 255>>
    end
  end
end
