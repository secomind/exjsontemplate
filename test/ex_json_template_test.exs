#
# This file is part of ExJSONTemplate.
#
# Copyright 2020 Ispirata Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule ExJSONTemplateTest do
  use ExUnit.Case
  alias ExJSONTemplate

  describe "render literals" do
    test "render string literal" do
      assert ExJSONTemplate.compile_template("foo bar") == {:ok, "foo bar"}
    end

    test "render number literal" do
      assert ExJSONTemplate.compile_template(42) == {:ok, 42}
    end
  end

  describe "render string interpolation" do
    test "using a map as input" do
      {:ok, compiled_template} = ExJSONTemplate.compile_template("Hello {{ $.first_name }}!")

      map = %{"first_name" => "Foo", "last_name" => "Bar"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, "Hello Foo!"}
    end

    test "which begins with {{ using a map as input" do
      {:ok, compiled_template} = ExJSONTemplate.compile_template("{{ $.first_name }} ")

      map = %{"first_name" => "Foo", "last_name" => "Bar"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, "Foo "}
    end

    test "when using multiple interpolations" do
      template = "x: {{ $.x }}, y: {{ $.y }}, z: 0"
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"x" => 0.5, "y" => -1.0, "t" => 5.3}
      expected_rendered = "x: 0.5, y: -1.0, z: 0"
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, expected_rendered}
    end

    test "inside of an array" do
      template = %{"data" => ["x: {{ $.x }}", "y: {{ $.y }}", "z: 0"]}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"x" => 0.5, "y" => -1.0, "t" => 5.3}
      expected_rendered = %{"data" => ["x: 0.5", "y: -1.0", "z: 0"]}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, expected_rendered}
    end
  end

  describe "triple braces operator" do
    test "on a number" do
      template = %{"the_number" => "{{{ $.num }}}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"num" => 42}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"the_number" => 42}}
    end

    test "do not parse number" do
      template = %{"string" => "{{{ $.the_string }}}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"the_string" => "42"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"string" => "42"}}
    end

    test "nested object" do
      template = %{"test" => "{{{ $.k }}}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"k" => %{"a" => %{"b" => "42"}}}

      assert ExJSONTemplate.render(compiled_template, map) ==
               {:ok, %{"test" => %{"a" => %{"b" => "42"}}}}
    end
  end

  describe "unquote operator" do
    test "on a number" do
      template = %{"the_number" => "{{& $.num }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"num" => 42}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"the_number" => 42}}
    end

    test "parse integer" do
      template = %{"the_number" => "{{& $.num }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"num" => "42"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"the_number" => 42}}
    end

    test "parse negative integer" do
      template = %{"the_number" => "{{& $.num }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"num" => "-42"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"the_number" => -42}}
    end

    test "parse float" do
      template = %{"the_number" => "{{& $.num }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"num" => "42.0"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"the_number" => 42.0}}
    end

    test "parse true" do
      template = %{"a" => "{{& $.bool }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"bool" => "true"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"a" => true}}
    end

    test "parse false" do
      template = %{"a" => "{{& $.bool }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"bool" => "false"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"a" => false}}
    end

    test "parse null" do
      template = %{"a" => "{{& $.n }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"n" => "null"}
      assert ExJSONTemplate.render(compiled_template, map) == {:ok, %{"a" => nil}}
    end

    test "fail on unquotable string" do
      template = %{"a" => "{{& $.u }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"u" => "hello"}
      assert ExJSONTemplate.render(compiled_template, map) == {:error, :cannot_unquote}
    end

    test "fail on invalid integer" do
      template = %{"the_number" => "{{& $.num }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"num" => "42z"}
      assert ExJSONTemplate.render(compiled_template, map) == {:error, :cannot_unquote}
    end

    test "fail on invalid float" do
      template = %{"the_number" => "{{& $.num }}"}
      {:ok, compiled_template} = ExJSONTemplate.compile_template(template)

      map = %{"num" => "42.1z"}
      assert ExJSONTemplate.render(compiled_template, map) == {:error, :cannot_unquote}
    end
  end
end
