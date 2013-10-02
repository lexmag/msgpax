ExUnit.start

defmodule MessagePack.Case do
  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: true
      use MessagePack
    end
  end
end
