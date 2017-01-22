# Changelog

## v1.1.0

* Added the `:include_struct_field` option for `Msgpax.Packer` protocol deriving.

## v1.0.0

* Renamed `Msgpax.Packer.transform/1` to `Msgpax.Packer.pack/1`, so all protocol
  implementations should be updated.
* Added the `:iodata` option to `Msgpax.pack/2` and `Msgpax.pack!/2`.
* Added the `Msgpax.Ext.Unpacker` behaviour.
* Added the `Msgpax.PlugParser` module which implements the `Plug.Parsers` behaviour.
* Added the `:fields` option for `@derive`.
