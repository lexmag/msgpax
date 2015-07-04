defmodule Msgpax do
  defmodule Binary do
    defstruct [:data]
  end

  def binary(bin) when is_binary(bin) do
    %Binary{data: bin}
  end

  alias __MODULE__.Packer
  alias __MODULE__.Unpacker

  defdelegate [pack(term), pack!(term)], to: Packer

  def unpack_slice(iodata, opts \\ %{}) do
    Unpacker.unpack(iodata, opts)
  end

  def unpack_slice!(iodata, opts \\ %{}) do
    Unpacker.unpack!(iodata, opts)
  end

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

  def unpack!(iodata, opts \\ %{}) do
    case unpack(iodata, opts) do
      {:ok, value} -> value
      {:error, reason} ->
        raise Msgpax.UnpackError, reason: reason
    end
  end
end
