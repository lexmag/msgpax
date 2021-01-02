defmodule Msgpax.Mixfile do
  use Mix.Project

  @source_url "https://github.com/lexmag/msgpax"
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
        source_url: @source_url,
        extras: ["CHANGELOG.md"]
      ]
    ]
  end

  def application(), do: []

  defp description() do
    "This library provides an API for serializing" <>
      " and de-serializing Elixir terms using the MessagePack format."
  end

  defp package() do
    [
      maintainers: ["Aleksei Magusev", "Andrea Leopardi"],
      licenses: ["ISC"],
      links: %{
        "Changelog" => "https://hexdocs.pm/msgpax/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.18", only: :dev, runtime: false},
      {:plug, "~> 1.0", optional: true}
    ]
  end
end
