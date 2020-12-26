defmodule Msgpax.FragmentTest do
  use Msgpax.Case, async: true

  alias Msgpax.Fragment

  doctest Msgpax.Fragment

  test "new/1" do
    assert %Msgpax.Fragment{} = fragment = Fragment.new(<<192>>)

    assert Msgpax.pack!(fragment) == <<192>>
  end

  test "inspect/1" do
    assert inspect(Fragment.new(<<192>>)) == "#Msgpax.Fragment<<<192>>>"
  end
end
