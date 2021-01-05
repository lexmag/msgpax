defmodule Msgpax.FragmentTest do
  use Msgpax.Case, async: true

  alias Msgpax.Fragment

  doctest Fragment

  test "new/1" do
    assert %Fragment{} = fragment = Fragment.new(<<192>>)

    assert Msgpax.pack!(fragment) == <<192>>
  end
end
