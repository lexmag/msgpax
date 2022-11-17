# Msgpax

![CI Status](https://github.com/lexmag/msgpax/workflows/CI/badge.svg)
[![Hex Version](https://img.shields.io/hexpm/v/msgpax.svg)](https://hex.pm/packages/msgpax)

Msgpax is a high-performance and comprehensive library for serializing and deserializing Elixir terms using the [MessagePack](http://msgpack.org/) format.

[Documentation is available online][docs].

## Features

* Packing and unpacking Elixir terms via [`Msgpax.pack/1`][docs-msgpax-pack-1] and [`Msgpax.unpack/1`][docs-msgpax-unpack-1] (and their bang! variants).
* Unpacking of partial slices of MessagePack-encoded terms via [`Msgpax.unpack_slice/1`][docs-msgpax-unpack_slice-1].
* Support for "Binary" and "Extension" MessagePack types via [`Msgpax.Bin`][docs-msgpax-bin] and [`Msgpax.Ext`][docs-msgpax-ext], respectively.
* Protocol-based packing through the [`Msgpax.Packer`][docs-msgpax-packer] protocol, that can be derived for user-defined structs.
* A Plug parser ([`Msgpax.PlugParser`][docs-msgpax-plug-parser]) to parse requests with MessagePack-encoded bodies.
* Support for MessagePack data fragment manipulation.

A detailed table that shows the relationship between Elixir types and MessagePack types can be found in the [documentation for the `Msgpax` module][docs-msgpax].

## Installation

Add `:msgpax` as a dependency in your `mix.exs` file:

```elixir
def deps do
  [{:msgpax, "~> 2.0"}]
end
```

Then, run `mix deps.get` in your shell to fetch the new dependency.

## License

Msgpax is released under [the ISC license](LICENSE).


[docs]: http://hexdocs.pm/msgpax
[docs-msgpax]: https://hexdocs.pm/msgpax/Msgpax.html
[docs-msgpax-pack-1]: http://hexdocs.pm/msgpax/Msgpax.html#pack/1
[docs-msgpax-unpack-1]: http://hexdocs.pm/msgpax/Msgpax.html#unpack/1
[docs-msgpax-unpack_slice-1]: http://hexdocs.pm/msgpax/Msgpax.html#unpack_slice/1
[docs-msgpax-packer]: http://hexdocs.pm/msgpax/Msgpax.Packer.html
[docs-msgpax-bin]: http://hexdocs.pm/msgpax/Msgpax.Bin.html
[docs-msgpax-ext]: http://hexdocs.pm/msgpax/Msgpax.Ext.html
[docs-msgpax-plug-parser]: http://hexdocs.pm/msgpax/Msgpax.PlugParser.html
