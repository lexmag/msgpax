defmodule Msgpax.Mixfile do
  use Mix.Project

  @version "2.2.4"

  def project do
    [
      app: :msgpax,
      version: @version,
      elixir: "~> 1.4",
      consolidate_protocols: Mix.env() != :test,
      description: description(),
      deps: deps(),
      package: package(),
      name: "Msgpax",
      docs: [
        main: "Msgpax",
        source_ref: "v#{@version}",
        source_url: "https://github.com/lexmag/msgpax"
      ]
    ]
  end

  def application(), do: []

  defp description() do
    "A fast and comprehensive library for serializing " <>
      "and deserializing Elixir terms using the MessagePack format."
  end

  defp package() do
    [
      maintainers: ["Aleksei Magusev", "Andrea Leopardi"],
      licenses: ["ISC"],
      links: %{"GitHub" => "https://github.com/lexmag/msgpax"}
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.20.0", only: :dev, runtime: false},
      {:plug, "~> 1.0", optional: true}
    ]
  end
end
