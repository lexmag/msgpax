defmodule Msgpax.Ext.Date do
  @moduledoc """
  Default implementation for `Date` type.

  Uses extension type `Msgpax.Ext101`.
  """
  use Msgpax.Ext

  defimpl Msgpax.Packer, for: Date do
    def pack(%{year: year, month: month, day: day}, options) do
      101
      |> Msgpax.Ext.new(<<year::15, month::4, day::5>>)
      |> @protocol.pack(options)
    end
  end

  defimpl Msgpax.Unpacker, for: Msgpax.Ext101 do
    def unpack(%{data: <<year::15, month::4, day::5>>}, _options) do
      with {:error, _reason} <- Date.new(year, month, day), do: :error
    end

    def unpack(_ext_101, _options), do: :error
  end
end
