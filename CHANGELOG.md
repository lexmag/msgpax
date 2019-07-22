# Changelog

## v2.2.4

* Optimized list and map packing.

## v2.2.3

* Optimized packing by generating less garbage.

## v2.2.2

* Fixed bare struct unpacking in `Msgpax.PlugParser`—the same behaviour when unpacking maps.

## v2.2.1

* Fixed deprecation warnings for using non-empty lists with the Collectable protocol.

## v2.2.0

* Added the `:unpacker` option support in `Msgpax.PlugParser`.

## v2.1.1

* Made unpacking even slightly more optimized.

## v2.1.0

* Added support for the Timestamp extension type.
* Improved handling of reserved extension types—unpacking will not fail for reserved extension types added in future.

## v2.0.0

* Optimized unpacking by using single match context.
* Optimized packing by producing smaller iodata.

__Breaking changes:__

* Dropped support for Elixir versions before 1.4.
* Converted all error reasons to proper exceptions: non-raising functions now return `{:error, Msgpax.PackError.t | Msgpax.UnpackError.t}` in case of failure instead of `{:error, term}`.
* Stopped packing keyword lists as maps and started raising an exception when trying to pack a keyword list: from now on explicit conversion from keyword lists to maps is required, or alternatively the `Msgpax.Packer` protocol must be implemented for tuples.

## v1.1.0

* Added the `:include_struct_field` option for `Msgpax.Packer` protocol deriving.

## v1.0.0

* Added the `:iodata` option to `Msgpax.pack/2` and `Msgpax.pack!/2`.
* Added the `Msgpax.Ext.Unpacker` behaviour.
* Added the `Msgpax.PlugParser` module which implements the `Plug.Parsers` behaviour.
* Added the `:fields` option for `@derive`.

__Breaking changes:__

* Renamed `Msgpax.Packer.transform/1` to `Msgpax.Packer.pack/1`, so all protocol
  implementations should be updated.
