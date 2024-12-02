defmodule KnotTest do
  use ExUnit.Case
  doctest Knot

  test "greets the world" do
    assert Knot.hello() == :world
  end
end
