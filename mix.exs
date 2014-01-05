defmodule MessagePack.Mixfile do
  use Mix.Project

  def project do
    [ app: :message_pack,
      version: "0.1.0",
      elixir: "~> 0.11",
      deps: deps ]
  end

  def application, do: []

  defp deps, do: []
end
