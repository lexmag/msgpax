defmodule Msgpax.Mixfile do
  use Mix.Project

  def project do
    [app: :msgpax,
     version: "0.8.1",
     elixir: "~> 1.0",
     consolidate_protocols: Mix.env != :test,
     description: description(),
     deps: deps(),
     package: package()]
  end

  def application(), do: []

  defp description() do
    "This library provides an API for serializing" <>
    " and de-serializing Elixir terms using the MessagePack format"
  end

  defp package() do
    [files: ["lib", "mix.exs", "README.md", "LICENSE"],
     contributors: ["Aleksei Magusev"],
     licenses: ["ISC"],
     links: %{"GitHub" => "https://github.com/lexmag/msgpax"}]
  end

  defp deps() do
    [{:earmark, ">= 0.0.0", only: :docs},
     {:ex_doc, ">= 0.0.0", only: :docs}]
  end
end
