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
iex> squad = Msgpax.pack([300, "Spartans"])
<<146, 205, 1, 44, 168, 83, 112, 97, 114, 116, 97, 110, 115>>
iex> Msgpax.unpack(squad)
[300, "Spartans"]
```

Furthermore, there are `to_msgpack` and `from_msgpack` macros available:

```elixir
defmodule TrojanHorse do
  use Msgpax

  def hide(number) do
    to_msgpack([number, "warriors"])
  end

  def show(bin) do
    case from_msgpack(bin) do
      [number, "warriors"] -> number
      _ -> raise ArgumentError
    end
  end
end
```

## License

This software is licensed under [the ISC license](LICENSE).
