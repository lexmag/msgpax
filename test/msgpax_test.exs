defmodule MsgpaxTest do
  use Msgpax.Case, async: true

  doctest Msgpax

  alias Msgpax.PackError
  alias Msgpax.UnpackError

  defmodule User do
    @derive [Msgpax.Packer]
    defstruct [:name]
  end

  defmodule UserWithAge do
    @derive [{Msgpax.Packer, fields: [:name]}]
    defstruct [:name, :age]
  end

  defmodule UserAllFields do
    @derive [{Msgpax.Packer, include_struct_field: true}]
    defstruct [:name]
  end

  defmodule UserDerivingStructField do
    @derive [{Msgpax.Packer, fields: [:name, :__struct__]}]
    defstruct [:name]
  end

  test "fixstring" do
    assert_format build_string(0), <<160>>
    assert_format build_string(31), <<191>>
  end

  test "string 8" do
    assert_format build_string(32), <<217, 32>>
    assert_format build_string(255), <<217, 255>>
  end

  test "string 16" do
    assert_format build_string(0x100), <<218, 0x100::16>>
    assert_format build_string(0xFFFF), <<218, 0xFFFF::16>>
  end

  test "string 32" do
    assert_format build_string(0x10000), <<219, 0x10000::32>>
  end

  test "binary 8" do
    assert_format build_bytes(1), <<0xC4, 1>>, build_string(1)
    assert_format build_bytes(255), <<0xC4, 255>>, build_string(255)

    assert_format build_bytes(1), <<0xC4, 1>>, {build_bytes(1), [binary: true]}
    assert_format build_bytes(255), <<0xC4, 255>>, {build_bytes(255), [binary: true]}
  end

  test "binary 16" do
    assert_format build_bytes(0x100), <<0xC5, 0x100::16>>, build_string(0x100)
    assert_format build_bytes(0xFFFF), <<0xC5, 0xFFFF::16>>, build_string(0xFFFF)
  end

  test "binary 32" do
    assert_format build_bytes(0x10000), <<0xC6, 0x10000::32>>, build_string(0x10000)
  end

  test "fixarray" do
    assert_format build_list(0), <<144>>
    assert_format build_list(15), <<159>>
  end

  test "array 16" do
    assert_format build_list(16), <<220, 16::16>>
    assert_format build_list(0xFFFF), <<220, 0xFFFF::16>>
  end

  test "array 32" do
    assert_format build_list(0x10000), <<221, 0x10000::32>>
  end

  test "fixmap" do
    assert_format build_map(0), <<128>>
    assert_format build_map(15), <<143>>
  end

  test "map 16" do
    assert_format build_map(16), <<222, 16::16>>
    assert_format build_map(0xFFFF), <<222, 0xFFFF::16>>
  end

  test "map 32" do
    assert_format build_map(0x10000), <<223, 0x10000::32>>
  end

  test "booleans" do
    assert_format false, <<194>>
    assert_format true, <<195>>
  end

  test "nil" do
    assert_format nil, <<192>>
  end

  test "atoms" do
    assert_format :ok, <<162>>, "ok"
    assert_format Atom, <<171>>, "Elixir.Atom"
  end

  test "floats" do
    assert_format 42.1, <<203>>

    for {packed, value} <- %{
          # 32-bit
          <<202, 0x7FC00000::32>> => Msgpax.NaN,
          <<202, 0x7F800000::32>> => Msgpax.Infinity,
          <<202, 0xFF800000::32>> => Msgpax.NegInfinity,
          # 64-bit
          <<203, 0x7FF8::16, 0::48>> => Msgpax.NaN,
          <<203, 0x7FF0::16, 0::48>> => Msgpax.Infinity,
          <<203, 0xFFF0::16, 0::48>> => Msgpax.NegInfinity
        } do
      assert Msgpax.unpack(packed) ==
               {:error, %Msgpax.UnpackError{reason: {:nonfinite_float, value}}}

      assert Msgpax.unpack(packed, nonfinite_floats: true) == {:ok, value}
    end

    assert Msgpax.Packer.pack_nan() == <<203, -1::64>>
    assert Msgpax.Packer.pack_infinity(:positive) == <<203, 0x7FF0::16, 0::48>>
    assert Msgpax.Packer.pack_infinity(:negative) == <<203, 0xFFF0::16, 0::48>>
  end

  test "positive fixint" do
    assert_format 0, <<0>>
    assert_format 127, <<127>>
  end

  test "uint 8" do
    assert_format 128, <<204>>
    assert_format 255, <<204>>
  end

  test "uint 16" do
    assert_format 256, <<205>>
    assert_format 65535, <<205>>
  end

  test "uint 32" do
    assert_format 65536, <<206>>
    assert_format 4_294_967_295, <<206>>
  end

  test "uint 64" do
    assert_format 4_294_967_296, <<207>>
  end

  test "negative fixint" do
    assert_format -1, <<255>>
    assert_format -32, <<224>>
  end

  test "int 8" do
    assert_format -33, <<208>>
    assert_format -128, <<208>>
  end

  test "int 16" do
    assert_format -129, <<209>>
    assert_format -32768, <<209>>
  end

  test "int 32" do
    assert_format -32769, <<210>>
    assert_format -2_147_483_648, <<210>>
  end

  test "int 64" do
    assert_format -2_147_483_649, <<211>>
  end

  test "complex structures" do
    data = %{[[123, "foo"], [true]] => [nil, -45, [%{[] => 10.0}]]}
    assert_format data, <<>>, data
    assert_format [data], <<>>, [data]
  end

  test "bitstring" do
    assert Msgpax.pack([42, <<5::3>>]) == {:error, %PackError{reason: {:not_encodable, <<5::3>>}}}
  end

  test "fragment" do
    assert {:ok, %Msgpax.Fragment{} = fragment} = Msgpax.pack_fragment("bar", iodata: false)
    assert Msgpax.pack!(%{foo: fragment}) |> Msgpax.unpack!() == %{"foo" => "bar"}

    assert %Msgpax.Fragment{} = fragment = Msgpax.pack_fragment!("foo")
    assert Msgpax.pack!([false, fragment]) |> Msgpax.unpack!() == [false, "foo"]
  end

  test "too big data" do
    assert Msgpax.pack([true, -9_223_372_036_854_775_809]) ==
             {:error, %PackError{reason: {:too_big, -9_223_372_036_854_775_809}}}
  end

  test "pack/2 with the :iodata option" do
    assert Msgpax.pack([], iodata: true) == {:ok, [144]}
    assert Msgpax.pack([], iodata: false) == {:ok, <<144>>}

    assert Msgpax.pack([42, <<5::3>>], iodata: false) ==
             {:error, %PackError{reason: {:not_encodable, <<5::3>>}}}
  end

  test "protocol not implemented" do
    assert {:error, %Protocol.UndefinedError{}} = Msgpax.pack([{}])
  end

  test "pack!/2 with the :iodata option" do
    assert Msgpax.pack!([], iodata: true) == [144]
    assert Msgpax.pack!([], iodata: false) == <<144>>

    assert_raise Msgpax.PackError, fn ->
      Msgpax.pack!([42, <<5::3>>], iodata: false)
    end
  end

  test "excess bytes" do
    assert Msgpax.unpack(<<255, 1, 2>>) ==
             {:error, %UnpackError{reason: {:excess_bytes, <<1, 2>>}}}
  end

  test "invalid format" do
    assert Msgpax.unpack(<<145, 191>>) == {:error, %UnpackError{reason: {:invalid_format, 191}}}
    assert Msgpax.unpack(<<193, 1>>) == {:error, %UnpackError{reason: {:invalid_format, 193}}}
  end

  test "incomplete binary" do
    assert Msgpax.unpack(<<147, 1, 2>>) == {:error, %UnpackError{reason: :incomplete}}
    assert_raise ArgumentError, fn -> Msgpax.unpack([<<5::3>>]) end
  end

  test "unpack_slice/1" do
    assert Msgpax.unpack_slice(<<255, 1>>) == {:ok, -1, <<1>>}
    assert_raise ArgumentError, fn -> Msgpax.unpack([<<5::3>>]) end
  end

  test "deriving" do
    assert Msgpax.pack!(%User{name: "Lex"}) == Msgpax.pack!(%{name: "Lex"})

    assert_raise Protocol.UndefinedError, fn ->
      Msgpax.pack!(%URI{})
    end

    assert Msgpax.pack!(%UserWithAge{name: "Luke", age: 9}) == Msgpax.pack!(%{name: "Luke"})

    expected = Msgpax.pack!(%{"__struct__" => UserAllFields, name: "Francine"})
    assert Msgpax.pack!(%UserAllFields{name: "Francine"}) == expected

    expected = Msgpax.pack!(%{"__struct__" => UserDerivingStructField, name: "Juri"})
    assert Msgpax.pack!(%UserDerivingStructField{name: "Juri"}) == expected
  end

  test "timestamp ext" do
    string =
      if Version.match?(System.version(), "<= 1.5.1") do
        "0001-01-01T00:00:00.000000Z"
      else
        "0001-01-01T00:00:00.000001Z"
      end

    {:ok, datetime, 0} = DateTime.from_iso8601(string)
    assert_format datetime, <<>>

    {:ok, datetime, 0} = DateTime.from_iso8601("1970-01-01T00:00:00Z")
    assert_format datetime, <<>>

    datetime = DateTime.utc_now()
    assert_format datetime, <<>>

    string =
      if Version.match?(System.version(), "<= 1.5.2") do
        "9999-12-31T23:59:59.0000000Z"
      else
        "9999-12-31T23:59:59.9999999Z"
      end

    {:ok, datetime, 0} = DateTime.from_iso8601(string)
    assert_format datetime, <<>>
  end

  defp build_string(length) do
    String.duplicate(".", length)
  end

  defp build_list(length) do
    List.duplicate(nil, length)
  end

  defp build_bytes(size) do
    size |> build_string() |> Msgpax.Bin.new()
  end

  defp build_map(0) do
    %{}
  end

  defp build_map(size) do
    {0, true}
    |> Stream.iterate(fn {index, value} -> {index + 1, value} end)
    |> Enum.take(size)
    |> Enum.into(%{})
  end
end
