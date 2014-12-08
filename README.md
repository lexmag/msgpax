# Msgpax [![Build Status](https://travis-ci.org/lexmag/msgpax.svg)](https://travis-ci.org/lexmag/msgpax)

This library provides an API for serializing and de-serializing Elixir terms using the [MessagePack](http://msgpack.org/) format.

## Installation

Add Msgpax as a dependency in your `mix.exs` file:

```elixir
def deps do
  [{:msgpax, "~> 0.3"}]
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
