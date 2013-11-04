Code.require_file "../test_helper.exs", __DIR__

defmodule MessagePack.DeserializerSuite do
    defmodule BitStringTest do
    use MessagePack.Case

    defmacrop assert_unpack(prefix, value) do
      quote do
        assert unpack(<<unquote_splicing(prefix), unquote(value) :: binary>>) == unquote(value)
      end
    end

    test "fixstring" do
      assert unpack(<<160>>) == ""
      assert_unpack([191], string(31))
    end

    test "string 8" do
      assert_unpack([217, 32], string(32))
      assert_unpack([217, 255], string(255))
    end

    test "string 16" do
      assert_unpack([218, 1, 0], string(256))
      assert_unpack([218, 255, 255], string(65535))
    end

    test "string 32" do
      assert_unpack([219, 0, 1, 0, 0], string(65536))
    end

    test "bitstring" do
      assert_raise MessagePack.Deserializer.Error, "Invalid byte sequence", fn ->
        unpack(<<7 :: 3>>)
      end
    end
  end

  defmodule ListTest do
    use MessagePack.Case

    defmacrop assert_unpack(prefix, value) do
      quote do
        assert unpack(<<unquote_splicing(prefix), do_pack(unquote(value)) :: binary>>) == unquote(value)
      end
    end

    defp do_pack([{_, _} | _] = list) do
      bc { key, value } inlist list do
        <<pack(key) :: binary, pack(value) :: binary>>
      end
    end

    defp do_pack(list) do
      bc term inlist list, do: <<pack(term) :: binary>>
    end

    test "fixarray" do
      assert unpack(<<144>>) == []
      assert_unpack([159], array(15))
    end

    test "array 16" do
      assert_unpack([220, 0, 16], array(16))
      assert_unpack([220, 255, 255], array(65535))
    end

    test "array 32" do
      assert_unpack([221, 0, 1, 0, 0], array(65536))
    end

    test "fixmap" do
      assert unpack(<<128>>) == [{}]
      assert_unpack([143], map(15))
    end

    test "map 16" do
      assert_unpack([222, 0, 16], map(16))
      assert_unpack([222, 255, 255], map(65535))
    end

    test "map 32" do
      assert_unpack([223, 0, 1, 0, 0], map(65536))
    end
  end

  defmodule AtomTest do
    use MessagePack.Case

    test "nil" do
      assert unpack(<<192>>) == nil
    end

    test "false" do
      assert unpack(<<194>>) == false
    end

    test "true" do
      assert unpack(<<195>>) == true
    end
  end

  defmodule FloatTest do
    use MessagePack.Case

    test "float 32" do
      assert unpack(<<202, 66, 40, 102, 102>>) == 42.099998474121094
    end

    test "float 64" do
      assert unpack(<<203, 64, 69, 12, 204, 204, 204, 204, 205>>) == 42.1
    end
  end

  defmodule IntegerTest do
    use MessagePack.Case

    test "positive fixint" do
      assert unpack(<<0>>) == 0
      assert unpack(<<127>>) == 127
    end

    test "uint 8" do
      assert unpack(<<204, 128>>) == 128
      assert unpack(<<204, 255>>) == 255
    end

    test "uint 16" do
      assert unpack(<<205, 1, 0>>) == 256
      assert unpack(<<205, 255, 255>>) == 65535
    end

    test "uint 32" do
      assert unpack(<<206, 0, 1, 0, 0>>) == 65536
      assert unpack(<<206, 255, 255, 255, 255>>) == 4294967295
    end

    test "uint 64" do
      assert unpack(<<207, 0, 0, 0, 1, 0, 0, 0, 0>>) == 4294967296
    end

    test "negative fixint" do
      assert unpack(<<255>>) == -1
      assert unpack(<<224>>) == -32
    end

    test "int 8" do
      assert unpack(<<208, 223>>) == -33
      assert unpack(<<208, 128>>) == -128
    end

    test "int 16" do
      assert unpack(<<209, 255, 127>>) == -129
      assert unpack(<<209, 128, 0>>) == -32768
    end

    test "int 32" do
      assert unpack(<<210, 255, 255, 127, 255>>) == -32769
      assert unpack(<<210, 128, 0, 0, 0>>) == -2147483648
    end

    test "int 64" do
      assert unpack(<<211, 255, 255, 255, 255, 127, 255, 255, 255>>) == -2147483649
    end
  end
end
