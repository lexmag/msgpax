# Since we are only implementing extension 127, there is no need to define all
# other structs
for reserved_type <- -1..-1, type = Bitwise.band(reserved_type, 127) do
  reserved_ext_module = Module.concat(Msgpax, "ReservedExt#{type}")

  defmodule reserved_ext_module do
    @moduledoc false

    defstruct [:data]

    defimpl Msgpax.Packer, for: reserved_ext_module do
      def pack(%_{data: data}, options),
        do: Msgpax.Ext.__pack__(unquote(reserved_type), data, options)
    end
  end
end

defmodule Msgpax.ReservedExt do
  @moduledoc """
  Reserved extensions automatically get handled by Msgpax.
  """

  @doc false
  for reserved_type <- -128..-1, type = Bitwise.band(reserved_type, 127) do
    extension = Module.concat(Msgpax, "ReservedExt#{type}")

    def new(unquote(reserved_type), data) when is_binary(data) do
      struct(unquote(extension), data: data)
    end
  end
end
