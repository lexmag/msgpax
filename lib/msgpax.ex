defmodule Msgpax do
  @moduledoc ~S"""
  This module provides functions for serializing and deserializing Elixir terms
  using the [MessagePack](http://msgpack.org/) format.

  ## Data conversion

  The following table shows how Elixir types are serialized to MessagePack types
  and how MessagePack types are deserialized back to Elixir types.

  Elixir                            | MessagePack   | Elixir
  --------------------------------- | ------------- | -------------
  `nil`                             | nil           | `nil`
  `true`                            | boolean       | `true`
  `false`                           | boolean       | `false`
  `-1`                              | integer       | `-1`
  `1.25`                            | float         | `1.25`
  *N/A*¹                            | NaN           | `Msgpax.NaN`²
  *N/A*¹                            | +infinity     | `Msgpax.Infinity`²
  *N/A*¹                            | -infinity     | `Msgpax.NegInfinity`²
  `:ok`                             | string        | `"ok"`
  `Atom`                            | string        | `"Elixir.Atom"`
  `"text"`                          | string        | `"text"`
  `"\xFF\xFF"`                      | string        | `"\xFF\xFF"`
  `#Msgpax.Bin<"\xFF">`             | binary        | `"\xFF"`³
  `%{foo: "bar"}`                   | map           | `%{"foo" => "bar"}`
  `[foo: "bar"]`                    | map           | `%{"foo" => "bar"}`
  `[1, true]`                       | array         | `[1, true]`
  `#Msgpax.Ext<4, "02:12">`         | extension     | `#Msgpax.Ext<4, "02:12">`
  `#DateTime<2017-12-06 00:00:00Z>` | extension     | `#DateTime<2017-12-06 00:00:00Z>`

  ¹ `Msgpax.Packer` provides helper functions to facilitate the serialization of natively unsupported data types.

  ² NaN and ±infinity are not enabled by default. See `unpack/2` for for more information.

  ³ To deserialize back to `Msgpax.Bin` structs see the `unpack/2` options.
  """

  alias __MODULE__.Packer
  alias __MODULE__.Unpacker

  @doc """
  Serializes the given `term`.

  This function returns iodata by default; if you want to force the result to be
  a binary, you can use `IO.iodata_to_binary/1` or use the `:iodata` option (see
  the "Options" section below).

  This function returns `{:ok, iodata}` if the serialization is successful,
  `{:error, exception}` otherwise, where `exception` is a `Msgpax.PackError`
  struct which can be raised or converted to a more human-friendly error
  message with `Exception.message/1`. See `Msgpax.PackError` for all the
  possible reasons for a packing error.

  ## Options

    * `:iodata` - (boolean) if `true`, this function returns the encoded term as
      iodata, if `false` as a binary. Defaults to `true`.

  ## Examples

      iex> {:ok, packed} = Msgpax.pack("foo")
      iex> IO.iodata_to_binary(packed)
      <<163, 102, 111, 111>>

      iex> Msgpax.pack(20000000000000000000)
      {:error, %Msgpax.PackError{reason: {:too_big, 20000000000000000000}}}

      iex> Msgpax.pack("foo", iodata: false)
      {:ok, <<163, 102, 111, 111>>}

  """
  @spec pack(term, Keyword.t()) :: {:ok, iodata} | {:error, Msgpax.PackError.t() | Exception.t()}
  def pack(term, options \\ []) when is_list(options) do
    iodata? = Keyword.get(options, :iodata, true)

    try do
      Packer.pack(term)
    catch
      :throw, reason ->
        {:error, %Msgpax.PackError{reason: reason}}

      :error, %Protocol.UndefinedError{protocol: Msgpax.Packer} = exception ->
        {:error, exception}
    else
      iodata when iodata? ->
        {:ok, iodata}

      iodata ->
        {:ok, IO.iodata_to_binary(iodata)}
    end
  end

  @doc """
  Works as `pack/1`, but raises if there's an error.

  This function works like `pack/1`, except it returns the `term` (instead of
  `{:ok, term}`) if the serialization is successful or raises a
  `Msgpax.PackError` exception otherwise.

  ## Options

  This function accepts the same options as `pack/2`.

  ## Examples

      iex> "foo" |> Msgpax.pack!() |> IO.iodata_to_binary()
      <<163, 102, 111, 111>>

      iex> Msgpax.pack!(20000000000000000000)
      ** (Msgpax.PackError) too big value: 20000000000000000000

      iex> Msgpax.pack!("foo", iodata: false)
      <<163, 102, 111, 111>>

  """
  @spec pack!(term, Keyword.t()) :: iodata | no_return
  def pack!(term, options \\ []) do
    case pack(term, options) do
      {:ok, result} ->
        result

      {:error, exception} ->
        raise exception
    end
  end

  @doc """
  Serializes `term` and turns the result into a `Msgpax.Fragment`.

  This function returns `{:ok, fragment}` if the serialization is successful,
  `{:error, exception}` otherwise, where `exception` is a `Msgpax.PackError`
  struct which can be raised or converted to a more human-friendly error
  message with `Exception.message/1`. See `Msgpax.PackError` for all the
  possible reasons for a packing error.

  This is useful for optimization, for instance, to avoid packing heavy terms
  repetitively.

  Another good use case for fragments would be data encapsulation. For example,
  if we want to "interpolate" some MessagePack data into the payload without
  having to unpack and pack them.

  ## Options

  This function accepts the same options as `pack/2`.

  ## Examples

      iex> {:ok, fragment} = Msgpax.pack_fragment("HUGE")
      iex> {:ok, packed} = Msgpax.pack([fragment, fragment])
      iex> IO.iodata_to_binary(packed)
      <<146, 164, 72, 85, 71, 69, 164, 72, 85, 71, 69>>

  """
  @spec pack_fragment(term, Keyword.t()) ::
          {:ok, Msgpax.Fragment.t()} | {:error, Msgpax.PackError.t() | Exception.t()}
  def pack_fragment(term, options \\ []) do
    with {:ok, packed} <- Msgpax.pack(term, options) do
      {:ok, Msgpax.Fragment.new(packed)}
    end
  end

  @doc """
  Works as `pack_fragment/2`, but raises if there's an error.

  This function works like `pack_fragment!/2`, except it returns the `fragment` (instead of
  `{:ok, fragment}`) if the serialization is successful or raises a `Msgpax.PackError`
  exception otherwise.

  ## Options

  This function accepts the same options as `pack_fragment/2`.

  ## Examples

      iex> fragment = Msgpax.pack_fragment!("HUGE")
      iex> {:ok, packed} = Msgpax.pack([fragment, fragment])
      iex> IO.iodata_to_binary(packed)
      <<146, 164, 72, 85, 71, 69, 164, 72, 85, 71, 69>>

  """
  @spec pack_fragment!(term, Keyword.t()) :: Msgpax.Fragment.t() | no_return()
  def pack_fragment!(term, options \\ []) do
    case pack_fragment(term, options) do
      {:ok, fragment} -> fragment
      {:error, exception} -> raise exception
    end
  end

  @doc """
  Deserializes part of the given `iodata`.

  This function works like `unpack/2`, but instead of requiring the input to be
  a MessagePack-serialized term with nothing after that, it accepts leftover
  bytes at the end of `iodata` and only deserializes the part of the input that
  makes sense. It returns `{:ok, term, rest}` if deserialization is successful,
  `{:error, exception}` otherwise (where `exception` is a `Msgpax.UnpackError`
  struct).

  See `unpack/2` for more information on the supported options.

  ## Examples

      iex> Msgpax.unpack_slice(<<163, "foo", "junk">>)
      {:ok, "foo", "junk"}

      iex> Msgpax.unpack_slice(<<163, "fo">>)
      {:error, %Msgpax.UnpackError{reason: {:invalid_format, 163}}}

  """
  @spec unpack_slice(iodata, Keyword.t()) :: {:ok, any, binary} | {:error, Msgpax.UnpackError.t()}
  def unpack_slice(iodata, options \\ []) when is_list(options) do
    try do
      iodata
      |> IO.iodata_to_binary()
      |> Unpacker.unpack(options)
    catch
      :throw, reason ->
        {:error, %Msgpax.UnpackError{reason: reason}}
    else
      {value, rest} ->
        {:ok, value, rest}
    end
  end

  @doc """
  Works like `unpack_slice/2` but raises in case of error.

  This function works like `unpack_slice/2`, but returns just `{term, rest}` if
  deserialization is successful and raises a `Msgpax.UnpackError` exception if
  it's not.

  ## Examples

      iex> Msgpax.unpack_slice!(<<163, "foo", "junk">>)
      {"foo", "junk"}

      iex> Msgpax.unpack_slice!(<<163, "fo">>)
      ** (Msgpax.UnpackError) invalid format, first byte: 163

  """
  @spec unpack_slice!(iodata, Keyword.t()) :: {any, binary} | no_return
  def unpack_slice!(iodata, options \\ []) do
    case unpack_slice(iodata, options) do
      {:ok, value, rest} ->
        {value, rest}

      {:error, exception} ->
        raise exception
    end
  end

  @doc """
  Deserializes the given `iodata`.

  This function deserializes the given `iodata` into an Elixir term. It returns
  `{:ok, term}` if the deserialization is successful, `{:error, exception}`
  otherwise, where `exception` is a `Msgpax.UnpackError` struct which can be
  raised or converted to a more human-friendly error message with
  `Exception.message/1`. See `Msgpax.UnpackError` for all the possible reasons
  for an unpacking error.

  ## Options

    * `:binary` - (boolean) if `true`, then binaries are decoded as `Msgpax.Bin`
      structs instead of plain Elixir binaries. Defaults to `false`.

    * `:ext` - (module) a module that implements the `Msgpax.Ext.Unpacker`
      behaviour. For more information, see the docs for `Msgpax.Ext.Unpacker`.

    * `:nonfinite_floats` - (boolean) if `true`, deserializes NaN and ±infinity to
      "signalling" atoms (see the "Data conversion" section), otherwise errors.
      Defaults to `false`.

  ## Examples

      iex> Msgpax.unpack(<<163, "foo">>)
      {:ok, "foo"}

      iex> Msgpax.unpack(<<163, "foo", "junk">>)
      {:error, %Msgpax.UnpackError{reason: {:excess_bytes, "junk"}}}

      iex> packed = Msgpax.pack!(Msgpax.Bin.new(<<3, 18, 122, 27, 115>>))
      iex> {:ok, bin} = Msgpax.unpack(packed, binary: true)
      iex> bin
      #Msgpax.Bin<<<3, 18, 122, 27, 115>>>

  """
  @spec unpack(iodata, Keyword.t()) :: {:ok, any} | {:error, Msgpax.UnpackError.t()}
  def unpack(iodata, options \\ []) do
    case unpack_slice(iodata, options) do
      {:ok, value, <<>>} ->
        {:ok, value}

      {:ok, _, bytes} ->
        {:error, %Msgpax.UnpackError{reason: {:excess_bytes, bytes}}}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Works like `unpack/2`, but raises in case of errors.

  This function works like `unpack/2`, but it returns `term` (instead of `{:ok,
  term}`) if deserialization is successful, otherwise raises a
  `Msgpax.UnpackError` exception.

  ## Example

      iex> Msgpax.unpack!(<<163, "foo">>)
      "foo"

      iex> Msgpax.unpack!(<<163, "foo", "junk">>)
      ** (Msgpax.UnpackError) found excess bytes: "junk"

      iex> packed = Msgpax.pack!(Msgpax.Bin.new(<<3, 18, 122, 27, 115>>))
      iex> Msgpax.unpack!(packed, binary: true)
      #Msgpax.Bin<<<3, 18, 122, 27, 115>>>

  """
  @spec unpack!(iodata, Keyword.t()) :: any | no_return
  def unpack!(iodata, options \\ []) do
    case unpack(iodata, options) do
      {:ok, value} ->
        value

      {:error, exception} ->
        raise exception
    end
  end
end
