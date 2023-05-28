defmodule Msgpax.Mixfile do
  use Mix.Project

  @source_url "https://github.com/lexmag/msgpax"
  @version "2.4.0"

  def project do
    [
      app: :msgpax,
      version: @version,
      elixir: "~> 1.6",
      consolidate_protocols: Mix.env() != :test,
      description: description(),
      deps: deps(),
      package: package(),
      name: "Msgpax",
      docs: [
        main: "Msgpax",
        source_ref: "v#{@version}",
        source_url: @source_url,
        extras: ["CHANGELOG.md"]
      ]
    ]
  end

  def application(), do: []

  defp description() do
    "A high-performance and comprehensive library for serializing " <>
      "and deserializing Elixir terms using the MessagePack format."
  end

  defp package() do
    [
      maintainers: ["Aleksei Magusev"],
      licenses: ["ISC"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.20", only: :dev, runtime: false},
      {:plug, "~> 1.0", optional: true}
    ]
  end
end
