ExUnit.start()

defmodule Msgpax.Case do
  use ExUnit.CaseTemplate

  using _ do
    quote do
      import unquote(__MODULE__)
    end
  end

  @new_map_ast quote(do: %{})

  defmacro assert_format(data, format) do
    round_trip(data, format, data, @new_map_ast)
  end

  defmacro assert_format(input, format, {output, opts}) do
    round_trip(input, format, output, opts)
  end

  defmacro assert_format(input, format, output) do
    round_trip(input, format, output, @new_map_ast)
  end

  defp round_trip(input, format, output, opts) do
    quote do
      assert {:ok, packed} = Msgpax.pack(unquote(input))
      assert <<unquote_splicing(format), _::bytes>> = IO.iodata_to_binary(packed)
      assert {:ok, unpacked} = Msgpax.unpack(packed, unquote(opts))
      assert unpacked == unquote(output)
    end
  end
end
