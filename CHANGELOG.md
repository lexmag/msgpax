# Changelog

## v2.4.0 – 2023-05-27

  * Dropped support for Elixir versions before 1.6.
  * Fixed a deprecation warning from `Bitwise`.

## v2.3.1 – 2022-11-16

  * Added support for iolists in `Msgpax.Ext`.
  * Fixed iolist `Msgpax.Fragment` inspecting.

## v2.3.0 – 2021-02-05

  * Introduced support for MessagePack data fragment manipulation.
  * Optimized unpacking even more for typical usage scenarios.
  * Fixed error raising in `Msgpax.pack/1` when protocol `Msgpax.Packer` is not implemented for the given data types.
  * Complete IEEE 754 support: added NaN and ±infinity.

## v2.2.4 – 2019-07-23

  * Optimized list and map packing.

## v2.2.3 – 2019-05-13

  * Optimized packing by generating less garbage.

## v2.2.2 – 2019-02-25

  * Fixed bare struct unpacking in `Msgpax.PlugParser`—the same behaviour when unpacking maps.

## v2.2.1 – 2019-01-29

  * Fixed deprecation warnings for using non-empty lists with the Collectable protocol.

## v2.2.0 – 2019-01-16

  * Added the `:unpacker` option support in `Msgpax.PlugParser`.

## v2.1.1 – 2018-02-02

  * Made unpacking even slightly more optimized.

## v2.1.0 – 2017-12-08

  * Added support for the Timestamp extension type.
  * Improved handling of reserved extension types—unpacking will not fail for reserved extension types added in future.

## v2.0.0 – 2017-05-23

  * Optimized unpacking by using single match context.
  * Optimized packing by producing smaller iodata.

__Breaking changes:__

  * Dropped support for Elixir versions before 1.4.
  * Converted all error reasons to proper exceptions: non-raising functions now return `{:error, Msgpax.PackError.t | Msgpax.UnpackError.t}` in case of failure instead of `{:error, term}`.
  * Stopped packing keyword lists as maps and started raising an exception when trying to pack a keyword list: from now on explicit conversion from keyword lists to maps is required, or alternatively the `Msgpax.Packer` protocol must be implemented for tuples.

## v1.1.0 – 2017-01-23

  * Added the `:include_struct_field` option for `Msgpax.Packer` protocol deriving.

## v1.0.0 – 2016-08-23

  * Added the `:iodata` option to `Msgpax.pack/2` and `Msgpax.pack!/2`.
  * Added the `Msgpax.Ext.Unpacker` behaviour.
  * Added the `Msgpax.PlugParser` module which implements the `Plug.Parsers` behaviour.
  * Added the `:fields` option for `@derive`.

__Breaking changes:__

  * Renamed `Msgpax.Packer.transform/1` to `Msgpax.Packer.pack/1`, so all protocol implementations should be updated.
