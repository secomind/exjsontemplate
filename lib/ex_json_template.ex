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

defmodule ExJSONTemplate do
  @moduledoc """
  Implements a simple logic less templating system that allows to write map templates with a syntax
  that resembles mustache syntax, that can be used for JSON templating.
  """

  alias ExJSONTemplate.Interpolation
  alias ExJSONTemplate.Operation

  def compile_template(template) when is_map(template) do
    Enum.reduce_while(template, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case compile_template(v) do
        {:ok, compiled} -> {:cont, {:ok, Map.put(acc, k, compiled)}}
      end
    end)
  end

  def compile_template([]) do
    {:ok, []}
  end

  def compile_template([head | tail] = _template) do
    with {:ok, compiled_tail} <- compile_template(tail),
         {:ok, compiled_head} <- compile_template(head) do
      {:ok, [compiled_head | compiled_tail]}
    end
  end

  def compile_template(template) when is_binary(template) do
    case parse_op(template) do
      {:ok, :interpolate, tokens} ->
        {:ok, %Interpolation{tokens: tokens}}

      {:ok, :literal, literal} ->
        {:ok, literal}

      {:ok, :triple_braces, path} ->
        {:ok, %Operation{op: :triple_braces, jsonpath: path}}

      {:ok, :unquote, path} ->
        {:ok, %Operation{op: :unquote, jsonpath: path}}
    end
  end

  def compile_template(template) do
    {:ok, template}
  end

  def parse_op(s), do: parse_op(s, :empty, [])

  def parse_op("", {:open, _op}, _acc) do
    {:error, :invalid}
  end

  def parse_op("", :literal, [acc]) do
    {:ok, :literal, acc}
  end

  def parse_op("", :interpolate, [{_op, _s} | _tail] = acc) do
    {:ok, :interpolate, Enum.reverse(acc)}
  end

  def parse_op("", :interpolate, [head | tail]) do
    {:ok, :interpolate, Enum.reverse([{:literal, head} | tail])}
  end

  def parse_op("", op, [acc]) do
    {:ok, op, acc}
  end

  def parse_op(<<"}}}", rest::binary>>, {:open, :triple_braces}, acc) do
    parse_op(rest, :triple_braces, acc)
  end

  def parse_op(<<"}}", rest::binary>>, {:open, :interpolate}, [acc | tail]) do
    case ExJSONPath.compile(acc) do
      {:ok, compiled} -> parse_op(rest, :interpolate, ["", {:jsonpath, compiled} | tail])
      _ -> {:error, :invalid_path}
    end
  end

  def parse_op(<<"}}", rest::binary>>, {:open, op}, acc) when op != :triple_braces do
    parse_op(rest, op, acc)
  end

  def parse_op(<<"\\{{{", rest::binary>>, op, acc) do
    parse_op(rest, op, acc)
  end

  def parse_op(<<"\\{{", rest::binary>>, op, acc) do
    parse_op(rest, op, acc)
  end

  def parse_op(<<"{{{", rest::binary>>, :empty, _acc) do
    parse_op(rest, {:open, :triple_braces}, [""])
  end

  def parse_op(<<"{{&", rest::binary>>, :empty, _acc) do
    parse_op(rest, {:open, :unquote}, [""])
  end

  def parse_op(<<"{{#", rest::binary>>, :empty, _acc) do
    parse_op(rest, {:open, :section}, [""])
  end

  def parse_op(<<"{{?", rest::binary>>, :empty, _acc) do
    parse_op(rest, {:open, :switch}, [""])
  end

  def parse_op(<<"{{", rest::binary>>, op, [acc | tail])
      when op in [:empty, :literal, :interpolate] do
    parse_op(rest, {:open, :interpolate}, ["", {:literal, acc} | tail])
  end

  def parse_op(<<"{{", rest::binary>>, :empty, _acc) do
    parse_op(rest, {:open, :interpolate}, [""])
  end

  def parse_op(<<c, rest::binary>>, :empty, _acc) do
    parse_op(rest, :literal, [<<c>>])
  end

  def parse_op(<<c, rest::binary>>, op, [acc | tail]) when op in [:literal, :interpolate] do
    parse_op(rest, op, [<<acc::binary, c>> | tail])
  end

  def parse_op(<<c, rest::binary>>, {:open, op}, [acc | tail]) do
    parse_op(rest, {:open, op}, [<<acc::binary, c>> | tail])
  end

  def parse_op(_s, _op, _acc) do
    {:error, :invalid}
  end

  def render([], _input) do
    {:ok, []}
  end

  def render([head | tail] = _compiled_template, input) do
    with {:ok, rendered_tail} <- render(tail, input),
         {:ok, rendered_head} <- render(head, input) do
      {:ok, [rendered_head | rendered_tail]}
    end
  end

  def render(%Interpolation{tokens: tokens}, input) do
    Enum.reduce_while(tokens, {:ok, ""}, fn
      {:literal, literal}, {:ok, acc} ->
        {:cont, {:ok, acc <> literal}}

      {:jsonpath, path}, {:ok, acc} ->
        case ExJSONPath.eval(input, path) do
          {:ok, [res]} -> {:cont, {:ok, acc <> to_string(res)}}
          _ -> {:halt, {:error, :cannot_render}}
        end
    end)
  end

  def render(%Operation{op: :triple_braces, jsonpath: path}, input) do
    case ExJSONPath.eval(input, path) do
      {:ok, [res]} -> {:ok, res}
      _ -> {:halt, {:error, :cannot_render}}
    end
  end

  def render(%Operation{op: :unquote, jsonpath: path}, input) do
    case ExJSONPath.eval(input, path) do
      {:ok, [res]} when is_binary(res) -> unquote_string(res)
      {:ok, [res]} -> {:ok, res}
      _ -> {:halt, {:error, :cannot_render}}
    end
  end

  def render(compiled_template, input) when is_map(compiled_template) do
    Enum.reduce_while(compiled_template, {:ok, %{}}, fn {k, v}, {:ok, acc} ->
      case render(v, input) do
        {:ok, rendered} -> {:cont, {:ok, Map.put(acc, k, rendered)}}
        error -> {:halt, error}
      end
    end)
  end

  def render(compiled_template, _input) do
    {:ok, compiled_template}
  end

  defp unquote_string("true") do
    {:ok, true}
  end

  defp unquote_string("false") do
    {:ok, false}
  end

  defp unquote_string("null") do
    {:ok, nil}
  end

  defp unquote_string(<<c, _rest::binary>> = num) when (c >= ?0 and c <= ?9) or c == ?- do
    case Integer.parse(num) do
      {i, ""} when is_integer(i) ->
        {:ok, i}

      {i, _rest} when is_integer(i) ->
        case Float.parse(num) do
          {f, ""} -> {:ok, f}
          _ -> {:error, :cannot_unquote}
        end

      _ ->
        {:error, :cannot_unquote}
    end
  end

  defp unquote_string(_string) do
    {:error, :cannot_unquote}
  end
end
