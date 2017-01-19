# Msgpax
[![Build Status](https://travis-ci.org/lexmag/msgpax.svg)](https://travis-ci.org/lexmag/msgpax)
[![Hex Version](https://img.shields.io/hexpm/v/msgpax.svg)](https://hex.pm/packages/msgpax)

This library provides an API for serializing and de-serializing Elixir terms using the [MessagePack](http://msgpack.org/) format.

[Documentation is available online][docs].

## Features

* Packing and unpacking Elixir terms via [`Msgpax.pack/1`][docs-msgpax-pack-1] and [`Msgpax.unpack/1`][docs-msgpax-unpack-1] (and their `!` bang variants).
* Unpacking of partial slices of MessagePack-encoded terms via [`Msgpax.unpack_slice/1`][docs-msgpax-unpack_slice-1].
* Support for "Binary" and "Extension" MessagePack types via [`Msgpax.Bin`][docs-msgpax-bin] and [`Msgpax.Ext`][docs-msgpax-ext], respectively.
* Protocol-based packing through the [`Msgpax.Packer`][docs-msgpax-packer] protocol, that can be derived for user-defined structs.
* A [`Plug.Parsers`][docs-plug-parsers] plug ([`Msgpax.PlugParser`][docs-msgpax-plug-parser]) to parse requests with MessagePack-encoded bodies.

A detailed table that shows the relationship between Elixir types and MessagePack types can be found in the [documentation for the `Msgpax` module][docs-msgpax].

## Installation

Add `:msgpax` as a dependency in your `mix.exs` file:

```elixir
def deps do
  [{:msgpax, "~> 1.0"}]
end
```

After you are done, run `mix deps.get` in your shell to fetch the dependencies.

## License

This software is licensed under [the ISC license](LICENSE).


[docs]: http://hexdocs.pm/msgpax
[docs-msgpax]: https://hexdocs.pm/msgpax/Msgpax.html
[docs-msgpax-pack-1]: http://hexdocs.pm/msgpax/Msgpax.html#pack/1
[docs-msgpax-unpack-1]: http://hexdocs.pm/msgpax/Msgpax.html#unpack/1
[docs-msgpax-unpack_slice-1]: http://hexdocs.pm/msgpax/Msgpax.html#unpack_slice/1
[docs-msgpax-packer]: http://hexdocs.pm/msgpax/Msgpax.Packer.html
[docs-msgpax-bin]: http://hexdocs.pm/msgpax/Msgpax.Bin.html
[docs-msgpax-ext]: http://hexdocs.pm/msgpax/Msgpax.Ext.html
[docs-msgpax-plug-parser]: http://hexdocs.pm/msgpax/Msgpax.PlugParser.html
[docs-plug-parsers]: http://hexdocs.pm/msgpax/Plug.Parsers.html
