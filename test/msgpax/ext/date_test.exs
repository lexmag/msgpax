defmodule Msgpax.Ext.DateTest do
  use Msgpax.Case, async: true

  test "`Date` has default extension implementation with code 101" do
    date = ~D[2023-08-23]
    assert_format date, <<0xC7, 3, 101, 15, 207, 23>>, date
  end
end
