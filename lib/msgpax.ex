defmodule Msgpax do
  @moduledoc """
  This module provides functions for serializing and de-serializing Elixir terms
  using the [MessagePack](http://msgpack.org/) format.

  ## Data conversion

  The following table shows how Elixir types are serialized to MessagePack types
  and how MessagePack types are de-serialized back to Elixir types.

  Elixir                         | MessagePack   | Elixir
  ------------------------------ | ------------- | -------------
  `nil`                          | nil           | `nil`
  `true`                         | boolean       | `true`
  `false`                        | boolean       | `false`
  `-1`                           | integer       | `-1`
  `1.25`                         | float         | `1.25`
  `:ok`                          | string        | `"ok"`
  `Atom`                         | string        | `"Elixir.Atom"`
  `"str"`                        | string        | `"str"`
  `"\xFF\xFF"`                   | string        | `"\xFF\xFF"`
  `#Msgpax.Bin<"\xFF">`          | binary        | `"\xFF"`
  `%{foo: "bar"}`                | map           | `%{"foo" => "bar"}`
  `[foo: "bar"]`                 | map           | `%{"foo" => "bar"}`
  `[1, true]`                    | array         | `[1, true]`
  `#Msgpax.Ext<4, "02:12">`      | extension     | `#Msgpax.Ext<4, "02:12">`

  """

  @type pack_error_reason ::
    {:too_big, any} |
    {:not_encodable, any}

  @type unpack_error_reason ::
    {:excess_bytes, binary} |
    {:bad_format, binary} |
    :incomplete |
    {:not_supported_ext, integer} |
    {:ext_unpack_failure, Msgpax.Ext.type, module, binary}

  alias __MODULE__.Packer
  alias __MODULE__.Unpacker

  @doc """
  Serializes `term`.

  This function returns iodata; if you want to force the result to be a binary,
  you can use `IO.iodata_to_binary/1`.

  This function returns `{:ok, iodata}` if the serialization is sucessful,
  `{:error, reason}` otherwise. Reason can be:

    * `{:bad_arg, term}` - means that the given argument is not serializable. For
      example, this is returned when you try to pack bits instead of a binary
      (as only binaries can be serialized).
    * `{:too_big, term}` - means that the given term is too big to be
      encoded. What "too big" means depends on the term being encoded; for
      example, integers larger than `18446744073709551616` are too big to be
      encoded with MessagePack.

  ## Examples

      iex> {:ok, packed} = Msgpax.pack("foo")
      iex> IO.iodata_to_binary(packed)
      <<163, 102, 111, 111>>

      iex> Msgpax.pack(20000000000000000000)
      {:error, {:too_big, 20000000000000000000}}

  """
  @spec pack(term) :: {:ok, iodata} | {:error, pack_error_reason}
  def pack(term) do
    Packer.pack(term)
  end

  @doc """
  Works as `pack/1`, but raises if there's an error.

  This function works like `pack/1`, except it returns the `term` (instead of
  `{:ok, term}`) if the serialization is successful and raises a
  `Msgpax.PackError` exception otherwise.

  ## Examples

      iex> "foo" |> Msgpax.pack!() |> IO.iodata_to_binary()
      <<163, 102, 111, 111>>

      iex> Msgpax.pack!(20000000000000000000)
      ** (Msgpax.PackError) value is too big: 20000000000000000000

  """
  @spec pack!(term) :: iodata | no_return
  def pack!(term) do
    Packer.pack!(term)
  end

  @doc """
  De-serializes part of the given `iodata`.

  This function works like `unpack/2`, but instead of requiring the input to be
  a MessagePack-serialized term with nothing after that, it accepts leftover
  bytes at the end of `iodata` and only de-serializes the part of the input that
  makes sense. It returns `{:ok, term, rest}` if de-serialization is successful,
  `{:error, reason}` otherwise.

  See `unpack/2` for more information on the supported options.

  ## Examples

      iex> Msgpax.unpack_slice(<<163, "foo", "junk">>)
      {:ok, "foo", "junk"}

      iex> Msgpax.unpack_slice(<<163, "fo">>)
      {:error, {:bad_format, 163}}

  """
  @spec unpack_slice(iodata, Keyword.t) :: {:ok, any, binary} | {:error, unpack_error_reason}
  def unpack_slice(iodata, opts \\ []) do
    Unpacker.unpack(iodata, Enum.into(opts, %{}))
  end

  @doc """
  Works like `unpack_slice/2` but raises in case of error.

  This function works like `unpack_slice/2`, but returns just `{term, rest}` if
  de-serialization is successful and raises a `Msgpax.UnpackError` exception if
  it's not.

  ## Examples

      iex> Msgpax.unpack_slice!(<<163, "foo", "junk">>)
      {"foo", "junk"}

      iex> Msgpax.unpack_slice!(<<163, "fo">>)
      ** (Msgpax.UnpackError) bad format: 163

  """
  @spec unpack_slice!(iodata, Keyword.t) :: {any, binary} | no_return
  def unpack_slice!(iodata, opts \\ []) do
    Unpacker.unpack!(iodata, Enum.into(opts, %{}))
  end

  @doc """
  De-serializes the given `iodata`.

  This function de-serializes the given `iodata` into an Elixir term. It returns
  `{:ok, term}` if de-serialization is successful, `{:error, reason}` otherwise.

  ## Options

    * `:binary` - (boolean) if `true`, then binaries are decoded as `Msgpax.Bin`
      structs instead of plain Elixir binaries.

  ## Examples

      iex> Msgpax.unpack(<<163, "foo">>)
      {:ok, "foo"}

      iex> Msgpax.unpack(<<163, "foo", "junk">>)
      {:error, {:excess_bytes, "junk"}}

      iex> packed = Msgpax.pack!(Msgpax.Bin.new(<<3, 18, 122, 27, 115>>))
      iex> {:ok, bin} = Msgpax.unpack(packed, binary: true)
      iex> bin
      #Msgpax.Bin<<<3, 18, 122, 27, 115>>>

  """
  @spec unpack(iodata, Keyword.t) :: {:ok, any} | {:error, unpack_error_reason}
  def unpack(iodata, opts \\ []) do
    case unpack_slice(iodata, Enum.into(opts, %{})) do
      {:ok, value, <<>>} ->
        {:ok, value}
      {:ok, _, bytes} ->
        {:error, {:excess_bytes, bytes}}
      {:error, _} = error ->
        error
    end
  end

  @doc """
  Works like `unpack/2`, but raises in case of errors.

  This function works like `unpack/2`, but it returns `term` (instead of `{:ok,
  term}`) if de-serialization is successful, otherwise raises a
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
  @spec unpack!(iodata, Keyword.t) :: any | no_return
  def unpack!(iodata, opts \\ []) do
    case unpack(iodata, Enum.into(opts, %{})) do
      {:ok, value} -> value
      {:error, reason} ->
        raise Msgpax.UnpackError, reason: reason
    end
  end
end
