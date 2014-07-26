defmodule MessagePack.Mixfile do
  use Mix.Project

  def project do
    [app: :message_pack,
     version: "0.2.0",
     elixir: "~> 0.11"]
  end

  def application, do: []
end
