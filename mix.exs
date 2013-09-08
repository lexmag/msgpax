defmodule MessagePack.Mixfile do
  use Mix.Project

  def project do
    [ app: :message_pack,
      version: "0.0.1",
      elixir: "~> 0.10.1",
      deps: deps ]
  end

  def application, do: []

  defp deps, do: []
end
