defmodule Msgpax.Ext.OverwriteTest do
  use Msgpax.Case, async: false

  test "default implementations can be overridden" do
    defmodule OverrideDefaultImplementation do
      use Msgpax.Ext

      defimpl Msgpax.Packer, for: Atom do
        def pack(atom, options) do
          3
          |> Msgpax.Ext.new(Atom.to_string(atom))
          |> @protocol.pack(options)
        end
      end

      defimpl Msgpax.Unpacker, for: Msgpax.Ext3 do
        def unpack(%{data: atom}, _options) do
          {:ok, String.to_existing_atom(atom)}
        end
      end
    end

    atom = :A
    assert_format atom, <<0xD4, 3, ?A>>, :A
  end

  test "default extensions can be overridden" do
    defmodule OverrideDefaultExtension do
      use Msgpax.Ext

      defimpl Msgpax.Packer, for: Date do
        def pack(_date, options) do
          2
          |> Msgpax.Ext.new("A")
          |> @protocol.pack(options)
        end
      end

      defimpl Msgpax.Unpacker, for: Msgpax.Ext2 do
        def unpack(%{data: date}, _options) do
          {:ok, date}
        end
      end
    end

    now = Date.utc_today()
    assert_format now, <<0xD4, 2, ?A>>, "A"
  end
end
