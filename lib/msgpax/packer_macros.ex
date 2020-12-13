
defmodule MsgPax.PackerMacros do
  defmacro excluded?(packer_type, do: block) do
    unless packer_type in Application.get_env(:msgpax, :exclude_packers, []) do
      block # AST as by quote do: unquote(block)
    end
  end
end
