# Msgpax [![Build Status](https://travis-ci.org/lexmag/msgpax.svg)](https://travis-ci.org/lexmag/msgpax)

This library provides an API for serializing and de-serializing Elixir terms using the [MessagePack](http://msgpack.org/) format.

## Installation

Add Msgpax as a dependency in your `mix.exs` file:

```elixir
def deps do
  [{:msgpax, "~> 0.5"}]
end
```

After you are done, run `mix deps.get` in your shell to fetch the dependencies.

## Usage

```iex
iex> {:ok, iodata} = Msgpax.pack([300, "Spartans"])
{:ok, [<<146>>, [<<205, 1, 44>>, [<<168>>, "Spartans"]]]}
iex> iodata = Msgpax.pack!([300, "Spartans"])
...
iex> {:ok, term} = Msgpax.unpack(iodata)
{:ok, [300, "Spartans"]}
iex> term = Msgpax.unpack!(iodata)
[300, "Spartans"]
```

#### Stream-oriented deserialization

```iex
iex> {term1, rest} = Msgpax.unpack_slice!(buffer)
{[1,2,3], <<4>>}
iex> {:ok, term2, rest} = Msgpax.unpack_slice(rest)
{:ok, 4, ""}
```

#### Binary format

```iex
iex> msgbin = Msgpax.binary(<<3, 18, 122, 27, 115>>)
%Msgpax.Binary{data: <<3, 18, 122, 27, 115>>}
iex> iodata = Msgpax.pack!(msgbin)
[<<196, 5>>, <<3, 18, 122, 27, 115>>]
...
iex> code = Msgpax.unpack!(iodata, %{binary: true})
%Msgpax.Binary{data: <<3, 18, 122, 27, 115>>}
```

## Data conversion

Elixir                         | MessagePack   | Elixir
------------------------------ | ------------- | -------------
`nil`                          | nil           | `nil`
`true`                         | boolean       | `true`
`false`                        | boolean       | `false`
`-1`                           | integer       | `-1`
`1.25`                         | float         | `1.25`
`:ok`                          | string        | `"ok"`
`Atom`                         | string        | `"Elixir.Atom"`
`"str"`                        | string        | `"str"`
`"\xFF\xFF"`                   | string        | `"\xFF\xFF"`
`%Msgpax.Binary{data: "\xFF"}` | binary        | `"\xFF"`
`%{foo: "bar"}`                | map           | `%{"foo" => "bar"}`
`[foo: "bar"]`                 | map           | `%{"foo" => "bar"}`
`[1, true]`                    | array         | `[1, true]`

## License

This software is licensed under [the ISC license](LICENSE).
