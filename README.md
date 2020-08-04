# ExJSONTemplate

ExJSONTemplate is an Elixir library which allows to write JSON templates in JSON.

## JSONTemplate

The most basic template operation is string interpolation:

```
in: {"user": "foo"}
template: {"greet": "Hello {{ $.user }}"}
out: {"greet": "Hello user"}
```

When using string interpolation scalar values (such as boolean, numbers, ...) are converted to
string by default:

```
in: {"num": 42}
template: {"answer": "The answer to the Ultimate Question of Life, the Universe, and Everything is {{ $.num }}"}
out: {"answer": "The answer to the Ultimate Question of Life, the Universe, and Everything is 42"}
```

Beware that non scalar values (such as arrays) cannot be converted to string, therefore a rendering
error is raised.

String interpolation can be avoided using `{{{ }}}`, which is the preferred method for templating
non string values:
```
in: {"number": 5}
t: {"a": "{{{ $.number }}}"}
out: {"a": 5}
```

`{{{ }}}` cannot be mixed with string interpolation, therefore `" {{{ $.test }}} a"` causes a
rendering error.

### `&` (Unquote) Operator

Unquote operator should be used when a scalar value is represented as string (such as `"5"`):

```
in: {"number": "5"}
t: {"a": "{{& $.number}}"}
out: {"a": 5}
```

If a string cannot be parsed as a scalar value, a rendering error is returned.

Unquote doesn't work with arrays and objects since they are not scalar values.

When `&` operator is applied to any non string value, it behaves like `{{{ }}}`:

```
in: {"number": 5}
t: {"a": "{{& $.number}}"}
out: {"a": 5}
```

`&` can be also used for non scalar values such as:

```
in: {"nums": [0, 1, 2, 3, 4, 5]}
t: {"nums2": ["{{& $.nums}}"]}
out: {"nums2": [[0, 1, 2, 3, 4, 5]]}
```

`&` never renders strings, therefore it cannot be used for string interpolation.

### `#` (Section) Operator

Array templates can be written using `#` section operator:

```
in: {"repo": [{"name": "Davide"}, {"name": "Riccardo"}]}
t: {"{{#repo}}": "Hello {{ $.name }}"}
out: ["Hello Davide", "Hello Riccardo"]
```

```
in: {"repo": ["Davide", "Riccardo"]}
t: {"{{#repo}}": "Hello {{ $ }}"}
out: ["Hello Davide", "Hello Riccardo"]
```

`#` operator can be also used for optional sections when applied to a boolean:

```
in: {"person": true, "name": "Davide"}
t: {"{{#person}}": "Hello {{$.name}}"}
out: "Hello Davide"
```

### `^` (Inverted Optional Section) Operator

Optional sections can be left out using `^` operator:

```
in: {"person": true, "name": "Davide"}
t: {"a": 1, "b": {"{{^person}}": "Hello {{$.name}}"}}
out: {"a": 1}
```

When the whole template is optional, `null` is rendered.

```
in: {"person": true, "name": "Davide"}
t: {"{{^person}}": "Hello {{$.name}}"}
out: null
```

`null` is rendered only when the inverted section is used as root object, otherwise the key
associated to the inverted section is deleted.

Each optional section object can have only a single key, (e.g. `{"{{^ $.a }}": 1, "{{^ $.b}}": 2}`
is invalid.

### `?` (Switch) Operator

Switch operator is useful when handling multiple cases, such as when dealing with enumerations:

```
in: {"num": 1}
t: {
  "message": {
    "{{?num}}": [
      {"case": 1, "template": "one"},
      {"case": 2, "template": "two"},
      {"case": 3, "template": "three"},
      {"template": "A lot."}
    ]
  }
}
out: {"message": "one"}
```

When a default template is not provided, it behaves like `^`:

```
in: {"num": 5}
t: {
  "message": {
    "{{?num}}": [
      {"case": 1, "template": "one"},
      {"case": 2, "template": "two"},
      {"case": 3, "template": "three"}
    ]
  }
}
out: {}
```

When an invalid default template `null` is provided a rendering error is returned:

```
in: {"num": 5}
t: {
  "message": {
    "{{?num}}": [
      {"case": 1, "template": "one"},
      {"case": 2, "template": "two"},
      {"case": 3, "template": "three"},
      null
    ]
  }
}
out: Rendering error
```

Switch operator can be used with boolens, and for testing if a value is non null as well, in this
case a more concise syntax can be used:

```
in: {"person": true, "name": "Davide"}
t: {"{{?person}}": {"true": "Hello {{$.name}}", "false": "Bye"}}
out: "Hello Davide"
```

```
in: {"person": false, "name": "Davide"}
t: {"message": {"{{?person}}": {"true": "Hello {{$.name}}", "false": "Bye"}}}
out: {"message": "Bye"}
```

```
in: {"person": false, "name": "Davide"}
t: {"message": {"{{?person}}": {"true": "Hello {{$.name}}"}}}
out: {}
```

### Interaction with JSONPath

JSONPath in simple scenarios evaluates to single values, however complex queries involving (`..`,
`*`, etc...) might evaluate to multiple values.

In the following example `$.user` evaluates to `["foo"]`, JSON template will always unwrap the item
at index 0 when using an interpolation with a JSONPath that evaluates to a single value.

```
in: {"user": "foo"}
template: {"greet": "Hello {{ $.user }}"}
out: {"greet": "Hello user"}
```

JSON path `$..user` evaluates to a "multiple result" (`["foo", "bar"]`) that is processed in the
same way of an array single result (`[["foo", "bar"]]`).

```
in: [{"user": "foo"}, %{"user" => "bar"}]
t: {"{{# $..user }}": ["Hello {{ $ }}]}
out: ["Hello foo", "Hello bar"]
```

### Escaping {{ and {{{

`{{` and `{{{` can be escaped using `\`, such as `\{{ $.foo }}` that is rendered as `\{{ $.foo }}`.
As a consequence`\{{ test }}` should be written `\\{{ test }}`. Same applies to $ keys, such as
`\$jsontemplate`.

### Template options

JSON templates can have an optional envelope that can be used for specifing json template version
and any additional option.

```
{
   "$jsontemplate": "1.0",
   "template: <<template here>>
}
```
