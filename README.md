# Msgpax [![Build Status](https://travis-ci.org/lexmag/msgpax.svg)](https://travis-ci.org/lexmag/msgpax)

This library provides an API for serializing and de-serializing Elixir terms using the [MessagePack](http://msgpack.org/) format.

## Installation

Add Msgpax as a dependency in your `mix.exs` file:

```elixir
def deps do
  [{:msgpax, github: "lexmag/msgpax"}]
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

## License

This software is licensed under [the ISC license](LICENSE).
