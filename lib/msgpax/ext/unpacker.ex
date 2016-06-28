defmodule Msgpax.Ext.Unpacker do
  @moduledoc """
  Behaviour to unpack `Msgpax.Ext` structs into arbitrary terms.

  Modules that implement this behaviour can be passed as the value of the `:ext`
  option in `Msgpax.unpack/2` and `Msgpax.unpack_slice/2` (and their bang!
  variants).

  See the documentation for `Msgpax.Ext` for usage examples.
  """

  @doc """
  Invoked when unpacking the given extension.

  It should return `{:ok, value}` to have Msgpax return `value` when unpacking
  the given extension, or `:error` if there's an error while unpacking.
  """
  @callback unpack(ext :: Msgpax.Ext.t) :: {:ok, any} | :error
end
