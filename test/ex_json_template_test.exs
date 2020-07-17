defmodule ExJSONTemplateTest do
  use ExUnit.Case
  doctest ExJSONTemplate

  test "greets the world" do
    assert ExJSONTemplate.hello() == :world
  end
end
