**[日本語版 README はこちら / Japanese README](README.ja.md)**

---

⚠️ **Maintenance Notice**

**This is a toy project and is NOT actively maintained.**

This package was created as an educational/experimental exploration of Pydantic-like validation in Julia.
While the code is functional, it should not be used in production environments.
Issues and pull requests may not receive responses.

---

> ⚠️ **Status**
>
> BoundaryTypes.jl is currently a **sample / experimental package** developed by
> [@daikichiba9511](https://github.com/daikichiba9511).
>
> The primary goal of this repository is to explore and document a
> _Julia-native approach to boundary validation_, inspired by—but not replicating—
> the developer experience of Pydantic.
>
> APIs may change without notice until a stable release is announced.

# BoundaryTypes.jl

**Pydantic-like validation at input boundaries, designed for Julia's type system.**

BoundaryTypes.jl provides a lightweight, declarative way to validate **external input**
(Dict / JSON / kwargs) _before_ constructing Julia domain types.

The core idea is simple:

> **Do validation at the boundary.
> Keep domain structs simple, typed, and always-valid.**

---

## Motivation

Julia excels at modeling domain logic with types and multiple dispatch.
However, validating _external input_ (API payloads, configs, user input, JSON)
often leads to either:

- ad-hoc checks scattered across code, or
- over-engineered schema systems that fight Julia’s type system.

BoundaryTypes.jl sits **between raw input and domain types**, providing:

- full-field validation with error aggregation (Pydantic-style UX)
- minimal macros and explicit control (Julia-style design)
- zero runtime cost once values cross the boundary

---

## Key Features

- ✅ Pydantic-like validation **only at input boundaries**
- ✅ Collect **all validation errors before failing**
- ✅ Declarative, composable validation rules
- ✅ Defaults and optional fields inferred from struct definitions
- ✅ Secret / redaction support for sensitive values
- ✅ Keeps domain structs small and idiomatic
- ✅ No heavy schemas, no global magic
- ✅ JSON parsing and validation support
- ✅ Immutable and mutable struct updates with `model_copy`
- ✅ Introspection with `show_rules`
- ✅ JSON Schema generation with `schema`
- ✅ Nested struct validation with automatic recursion

---

## Quick Example

```julia
using BoundaryTypes

@model struct Signup
    email::String
    password::String
    age::Int = 0
end

@rules Signup begin
    field(:email,
          regex(r"^[^@\s]+@[^@\s]+\.[^@\s]+$"))

    field(:password,
          minlen(12),
          regex(r"[A-Z]"),
          regex(r"[0-9]"),
          secret())

    field(:age,
          ge(0), le(150))
end

Signup(email="foo@example.com", password="short")
```

Output:

```
ValidationError with 2 error(s):
  - password [minlen]: string too short (got=***)
  - password [regex]: does not match required pattern (got=***)
```

---

## Design Philosophy

BoundaryTypes.jl intentionally **does not** try to replace Julia’s type system.

Instead, it enforces a clear separation:

```
[ External Input ]
        ↓
   model_validate / try_model_validate   ← validation happens here
        ↓
   Domain Struct      ← always valid
```

### Why this matters

- Domain structs stay clean and fast
- Validation logic is centralized and explicit
- Invalid states cannot leak into core logic
- Testing and reasoning become simpler

---

## Defining Models

### `@model`

Use `@model` to declare a domain struct.
BoundaryTypes automatically infers:

- required fields
- default values
- optional fields (`Union{Nothing,T}`)

```julia
@model struct User
    id::Int
    name::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end
```

Inference rules:

| Definition                      | Interpretation        |
| ------------------------------- | --------------------- |
| `x::T`                          | required              |
| `x::T = v`                      | default value         |
| `x::Union{Nothing,T}`           | optional              |
| `x::Union{Nothing,T} = nothing` | optional with default |

---

## Validation Rules

Validation rules are defined **outside** the struct using `@rules`.

```julia
@rules User begin
    field(:name, minlen(1))
    field(:age, ge(0))
    field(:nickname, minlen(3))  # only checked if value exists
end
```

### Available Rule Builders

#### String rules

- `minlen(n)` — minimum string/collection length
- `maxlen(n)` — maximum string/collection length
- `regex(re)` — pattern matching
- `email()` — email address validation
- `url()` — URL format validation
- `uuid()` — UUID format validation
- `choices(values)` — enum-like validation

#### Numeric rules

- `ge(n)` — greater than or equal (≥)
- `le(n)` — less than or equal (≤)
- `gt(n)` — strictly greater than (>)
- `lt(n)` — strictly less than (<)
- `between(min, max)` — range validation (inclusive)
- `multiple_of(n)` — divisibility check

#### Collection rules

- `each(rule)` — apply rule to each element

#### Presence rules

- `present()` — key must exist
- `notnothing()` — value must not be `nothing`

#### Security

- `secret()` — masks value in error messages and logs

#### Custom rules

```julia
custom(x -> x % 2 == 0; code=:even, msg="must be even")
```

Rules are composable and executed **without fail-fast**.

---

## Defaults and Optional Fields

### Defaults are validated

```julia
age::Int = 0
field(:age, ge(0))
```

If `age` is missing, `0` is used **and validated**.

### Optional fields (`Union{Nothing,T}`)

- Missing or `nothing` → OK by default
- Rules run only when a real value is present

```julia
nickname::Union{Nothing,String}
field(:nickname, minlen(3))
```

To enforce presence explicitly:

```julia
field(:nickname, present())
field(:nickname, notnothing())
```

---

## Parsing API

### `model_validate`

```julia
value = model_validate(T, raw)
```

- `raw`: `Dict`, `NamedTuple`, or keyword arguments
- Returns `T` on success
- Throws `ValidationError` on failure

### `try_model_validate`

```julia
ok, result = try_model_validate(T, raw)
```

- `ok == true` → `result::T`
- `ok == false` → `result::ValidationError`

### `model_validate_json`

```julia
value = model_validate_json(T, json_string)
```

- `json_string`: JSON-formatted string
- Parses the JSON string and validates it against type `T`
- Returns `T` on success
- Throws `ValidationError` on failure

Example:

```julia
json_str = """{"email":"user@example.com", "password":"SecurePass123", "age":25}"""
signup = model_validate_json(Signup, json_str)
```

### `try_model_validate_json`

```julia
ok, result = try_model_validate_json(T, json_string)
```

- `ok == true` → `result::T`
- `ok == false` → `result::ValidationError`
- Safe (non-throwing) version of `model_validate_json`

---

## Constructor Integration

### Manual Integration (Recommended)

To make validation the default experience:

```julia
User(; kwargs...) = model_validate(User, kwargs)
```

This allows:

```julia
User(name="Alice", age=-1)
```

…to automatically go through validation,
without exposing raw constructors to external input.

### Automatic Integration with `@validated_model`

The `@validated_model` macro automatically creates a validated keyword constructor:

```julia
@validated_model struct Account
    username::String
    email::String
    balance::Float64 = 0.0
end

@rules Account begin
    field(:username, minlen(3))
    field(:email, regex(r"@"))
    field(:balance, ge(0.0))
end

# Constructor automatically validates
acc = Account(username="alice", email="alice@example.com")
# Throws ValidationError if invalid
```

---

## Error Model

Each validation error contains:

- `path` — field path (supports nested fields: `[:address, :zipcode]`)
- `code` — machine-readable error code
- `message` — human-readable description
- `got` — offending value (masked if `secret()`)

Sensitive values are never leaked.

---

## Nested Struct Validation

BoundaryTypes.jl automatically validates nested structs that are registered with `@model`.

```julia
@model struct Address
    city::String
    zipcode::String
end

@rules Address begin
    field(:city, minlen(1))
    field(:zipcode, regex(r"^\d{5}$"))
end

@model struct User
    name::String
    address::Address  # Nested model
end

@rules User begin
    field(:name, minlen(2))
end

# Nested validation happens automatically
user = model_validate(User, Dict(
    :name => "Alice",
    :address => Dict(:city => "Tokyo", :zipcode => "12345")
))

# Error paths include nested field names
model_validate(User, Dict(
    :name => "Bob",
    :address => Dict(:city => "Osaka", :zipcode => "invalid")
))
# => ValidationError with 1 error(s):
#      - address.zipcode [regex]: does not match required pattern (got="invalid")
```

### Features

- **Automatic recursion**: Nested models are validated automatically
- **Deep nesting**: Supports arbitrary nesting depth
- **Clear error paths**: Errors show the full path (e.g., `address.zipcode`, `city.country.code`)
- **Optional nested fields**: Works with `Union{Nothing,ModelType}` fields
- **Nested defaults**: Supports default values for nested structs

### Example with Multiple Levels

```julia
@model struct Country
    name::String
    code::String
end

@rules Country begin
    field(:code, regex(r"^[A-Z]{2}$"))
end

@model struct City
    name::String
    country::Country
end

@model struct Office
    address::String
    city::City
end

# Deep nested validation
office = model_validate(Office, Dict(
    :address => "123 Main St",
    :city => Dict(
        :name => "Tokyo",
        :country => Dict(:name => "Japan", :code => "JP")
    )
))

# Error at any level is caught with full path
model_validate(Office, Dict(
    :address => "456 Elm St",
    :city => Dict(
        :name => "London",
        :country => Dict(:name => "UK", :code => "GBR")  # Invalid: should be 2 chars
    )
))
# => ValidationError: city.country.code [regex]: does not match required pattern
```

---

## Updating Models

### `model_copy` (Immutable Structs)

Create a new instance with updated field values:

```julia
user = model_validate(User, Dict(:name => "Alice", :email => "alice@example.com", :age => 25))
updated = model_copy(user, Dict(:age => 26))  # Returns new instance
```

- Validates the updated values by default
- Use `validate=false` to skip validation

### `model_copy!` (Mutable Structs)

Update a mutable struct instance in-place:

```julia
model_copy!(mutable_user, Dict(:age => 31))  # Modifies in-place
```

---

## Introspection

### `show_rules`

Display validation rules for a registered model type:

```julia
show_rules(Signup)
# Or specify an IO stream
show_rules(io, Signup)
```

### `schema`

Generate a JSON Schema (Draft 7) for a model:

```julia
json_schema = schema(Signup)
# Returns a Dict compatible with JSON Schema Draft 7
```

This is useful for:
- API documentation
- Client-side validation
- Integration with OpenAPI/Swagger

---

## Collection Validation

BoundaryTypes.jl supports validating collections (arrays, vectors, sets) with the `each(rule)` combinator.

### Basic Usage

```julia
@model struct Post
    title::String
    tags::Vector{String}
end

@rules Post begin
    field(:title, minlen(1))
    field(:tags, each(minlen(3)))  # Each tag must be at least 3 characters
end

# Valid
post = model_validate(Post, Dict(
    :title => "My Post",
    :tags => ["julia", "programming", "web"]
))

# Invalid - second tag is too short
model_validate(Post, Dict(
    :title => "My Post",
    :tags => ["julia", "ab", "web"]
))
# => ValidationError with 1 error(s):
#      - tags[1] [minlen]: too short (got="ab")
```

### Collection Length Validation

You can also validate the collection's length using `minlen` and `maxlen`:

```julia
@model struct Comment
    text::String
    tags::Vector{String}
end

@rules Comment begin
    field(:text, minlen(1), maxlen(280))  # Twitter-style limit
    field(:tags, minlen(1), maxlen(5))     # Between 1 and 5 tags
end
```

### Combining Rules

Multiple `each()` rules can be combined with collection-level constraints:

```julia
@model struct ScoreBoard
    scores::Vector{Int}
end

@rules ScoreBoard begin
    field(:scores, minlen(1), each(ge(0)), each(le(100)))
    # At least 1 score, all between 0 and 100
end
```

### Supported Collection Types

- `Vector{T}` / `Array{T}`
- `Set{T}`
- Any type implementing `AbstractArray` or `AbstractSet`

### Error Reporting

Validation errors include the element index in the path:

```julia
# Error at index 2
# => ValidationError: tags[2] [minlen]: too short
```

---

## What BoundaryTypes.jl Is _Not_

- ❌ A full schema system
- ❌ A serialization framework
- ❌ A replacement for Julia's type system
- ❌ A clone of Pydantic

It is a **boundary validation library**, by design.

---

## Requirements

- Julia **1.12+** (as specified in Project.toml)

Dependencies:
- JSON3 (for JSON parsing)

---

## Current Features

The following features are implemented and tested:

- ✅ `@model` and `@rules` macros for declarative validation
- ✅ `@validated_model` for automatic constructor validation
- ✅ `model_validate` / `try_model_validate` for Dict/NamedTuple input
- ✅ `model_validate_json` / `try_model_validate_json` for JSON strings
- ✅ `model_copy` / `model_copy!` for updating instances
- ✅ `show_rules` for introspection
- ✅ `schema` for JSON Schema generation
- ✅ Validation rules: `minlen`, `maxlen`, `regex`, `ge`, `le`, `gt`, `lt`, `between`, `multiple_of`, `email`, `url`, `uuid`, `choices`, `present`, `notnothing`, `secret`, `custom`, `each`
- ✅ Collection validation for `Vector{T}`, `Set{T}`, and other array-like types
- ✅ Advanced string validation (email, URL, UUID formats)
- ✅ Advanced numeric validation (strict inequalities, ranges, multiples)
- ✅ Type mismatch detection
- ✅ Extra field detection
- ✅ Default value validation
- ✅ Optional field handling (`Union{Nothing,T}`)
- ✅ Secret field masking in error messages
- ✅ Nested struct validation with automatic recursion

---

## Roadmap

Potential future extensions (without breaking the core design):

- Type coercion (`"123"` → `Int`)
- Nested collection validation (`Vector{ModelType}`)
- Cross-field validation
- i18n error messages

---

## License

MIT
