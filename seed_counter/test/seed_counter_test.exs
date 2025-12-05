defmodule SeedCounterTest do
  use ExUnit.Case
  doctest SeedCounter

  test "greets the world" do
    assert SeedCounter.hello() == :world
  end
end
