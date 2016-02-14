defmodule Msgpax do
  @moduledoc """
  This module provides functions for serializing and de-serializing Elixir terms
  using the [MessagePack](http://msgpack.org/) format.
  """

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
      ** (Msgpax.PackError) too big value: 20000000000000000000

  """
  def pack!(term) do
    Packer.pack!(term)
  end

  @doc """
  De-serializes the given `iodata` in a "stream-oriented" fashion.

  This function works like `unpack/2`, but instead of requiring the input to be
  a MessagePack-serialized term with nothing after that, it accepts leftover
  bytes at the end of `iodata`. It returns `{:ok, term, rest}` if
  de-serialization is successful, `{:error, reason}` otherwise.

  See `unpack/2` for more information on the supported options.

  ## Examples

      iex> Msgpax.unpack_slice(<<163, "foo", "junk">>)
      {:ok, "foo", "junk"}

      iex> Msgpax.unpack_slice(<<163, "fo">>)
      {:error, {:bad_format, 163}}

  """
  def unpack_slice(iodata, opts \\ %{}) do
    Unpacker.unpack(iodata, opts)
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
  def unpack_slice!(iodata, opts \\ %{}) do
    Unpacker.unpack!(iodata, opts)
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
      {:error, {:extra_bytes, "junk"}}

      iex> packed = Msgpax.pack!(Msgpax.Bin.new(<<3, 18, 122, 27, 115>>))
      iex> {:ok, bin} = Msgpax.unpack(packed, %{binary: true})
      iex> bin
      #Msgpax.Bin<<<3, 18, 122, 27, 115>>>

  """
  def unpack(iodata, opts \\ %{}) do
    case unpack_slice(iodata, opts) do
      {:ok, value, <<>>} ->
        {:ok, value}
      {:ok, _, bytes} ->
        {:error, {:extra_bytes, bytes}}
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
      ** (Msgpax.UnpackError) extra bytes follow after packet: "junk"

      iex> packed = Msgpax.pack!(Msgpax.Bin.new(<<3, 18, 122, 27, 115>>))
      iex> Msgpax.unpack!(packed, %{binary: true})
      #Msgpax.Bin<<<3, 18, 122, 27, 115>>>

  """
  def unpack!(iodata, opts \\ %{}) do
    case unpack(iodata, opts) do
      {:ok, value} -> value
      {:error, reason} ->
        raise Msgpax.UnpackError, reason: reason
    end
  end
end
