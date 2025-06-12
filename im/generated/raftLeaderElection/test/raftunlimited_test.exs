defmodule RaftUnlimitedTest do
  use ExUnit.Case
  doctest RaftUnlimited

  test "greets the world" do
    assert RaftUnlimited.hello() == :world
  end
end
