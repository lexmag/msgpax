defmodule Msgpax.PackerTest do
  use Msgpax.Case, async: true
  alias Msgpax.Packer

  test "pack/1 for Date" do
    assert [170 | "2015-01-01"] == Packer.pack(~D[2015-01-01])
  end

  test "pack/1 for DateTime" do
    {:ok, datetime, _utc_offset} = DateTime.from_iso8601("2015-01-01T23:50:07Z")
    
    assert [180 | "2015-01-01 23:50:07Z"] == Packer.pack(datetime)
  end

  test "pack/1 for NaiveDateTime" do
    assert [183 | "2015-01-01 23:50:07.001"] == Packer.pack(~N[2015-01-01 23:50:07.001])
  end
end
