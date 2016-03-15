# Msgpax
[![Build Status](https://travis-ci.org/lexmag/msgpax.svg)](https://travis-ci.org/lexmag/msgpax)
[![Hex Version](https://img.shields.io/hexpm/v/msgpax.svg)](https://hex.pm/packages/msgpax)

This library provides an API for serializing and de-serializing Elixir terms using the [MessagePack](http://msgpack.org/) format.

[Documentation is available online][docs-msgpax].

## Installation

Add Msgpax as a dependency in your `mix.exs` file:

```elixir
def deps do
  [{:msgpax, "~> 0.8"}]
end
```

After you are done, run `mix deps.get` in your shell to fetch the dependencies.

## Usage

```elixir
{:ok, iodata} = Msgpax.pack([300, "Spartans"])
# => {:ok, [<<146>>, [<<205, 1, 44>>, [<<168>>, "Spartans"]]]}
iodata = Msgpax.pack!([300, "Spartans"])
# ...
{:ok, term} = Msgpax.unpack(iodata)
# => {:ok, [300, "Spartans"]}
term = Msgpax.unpack!(iodata)
# => [300, "Spartans"]
```

#### Partial deserialization

```elixir
{term1, rest} = Msgpax.unpack_slice!(buffer)
# => {[1, 2, 3], <<4>>}
{:ok, term2, rest} = Msgpax.unpack_slice(rest)
# => {:ok, 4, ""}
```

#### Support for the "Binary" and "Extension" types

The "Binary" and the "Extension" types are supported through the [`Msgpax.Bin`][docs-msgpax-bin] and [`Msgpax.Ext`][docs-msgpax-ext] structs, respectively.

An example of usage for `Msgpax.Bin`:

```elixir
msgbin = Msgpax.Bin.new(<<3, 18, 122, 27, 115>>)
# => #Msgpax.Bin<<<3, 18, 122, 27, 115>>>
iodata = Msgpax.pack!(msgbin)
# => [<<196, 5>>, <<3, 18, 122, 27, 115>>]
# ...
code = Msgpax.unpack!(iodata, %{binary: true})
# => #Msgpax.Bin<<<3, 18, 122, 27, 115>>>
```

#### Deriving of the `Msgpax.Packer` protocol

```elixir
defmodule User do
  @derive [Msgpax.Packer]
  defstruct [:name]
end

Msgpax.pack!(%User{name: "Lex"})
# => [<<129>>, [[[<<164>>, "name"], [<<163>>, "Lex"]]]]
```

In the example above, information about the `User` struct is lost when decoding back to Elixir terms:

```elixir
%User{name: "Lex"} |> Msgpax.pack!() |> Msgpax.unpack!()
# => %{"name" => "Lex"}
```

You can overcome this by using something like [maptu][gh-maptu]:

```elixir
map = %User{name: "Lex"} |> Msgpax.pack!() |> Msgpax.unpack!()
Maptu.struct!(User, map)
# => %User{name: "Lex"}
```

## License

This software is licensed under [the ISC license](LICENSE).


[docs-msgpax]: http://hexdocs.pm/msgpax
[docs-msgpax-bin]: http://hexdocs.pm/msgpax/Msgpax.Bin.html
[docs-msgpax-ext]: http://hexdocs.pm/msgpax/Msgpax.Ext.html
[gh-maptu]: https://github.com/whatyouhide/maptu
