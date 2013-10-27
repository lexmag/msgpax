# MessagePack [![Build Status](https://travis-ci.org/lexmag/msgpack-elixir.png?branch=master)](https://travis-ci.org/lexmag/msgpack-elixir)

This library provides an API for serializing and de-serializing Elixir/Erlang terms using the [MessagePack](http://msgpack.org/) format.

## Installation

Add MessagePack as a dependency in your mix.exs file:

```elixir
def deps do
  [{ :message_pack, github: "lexmag/msgpack-elixir" }]
end
```

And run the `mix deps.get` command to fetch and compile the dependencies.

## Usage

```iex
iex> squad = MessagePack.pack([300, "Spartans"])
<<146, 205, 1, 44, 168, 83, 112, 97, 114, 116, 97, 110, 115>>
iex> MessagePack.unpack(squad)
[300, "Spartans"]
```

Furthermore, there are `to_msgpack` and `from_msgpack` macros available:

```elixir
defmodule TrojanHorse do
  use MessagePack

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

Copyright © 2013 Aleksey Magusev <lexmag@me.com>  
This work is free. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2,
as published by Sam Hocevar. See the [COPYING](https://github.com/lexmag/msgpack-elixir/blob/master/COPYING) file for more details.
