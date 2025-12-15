"""
    BoundaryTypes

A Pydantic-like validation library for Julia that provides comprehensive input validation
at system boundaries while maintaining Julia's type safety and philosophy.

# Design Philosophy

BoundaryTypes adopts a **two-layer architecture**:

```
[External Input]
   ↓
model_validate / try_model_validate   ← Pydantic-like (validate all fields)
   ↓
Domain struct                         ← Julia-like (always-valid)
```

## Domain Layer (Julia-like)
- `struct` definitions are thin, pure data containers
- Invariants are enforced via inner constructors with fail-fast behavior
- Never allows construction of invalid instances

## Boundary Layer (Pydantic-like UX)
- `model_validate(T, raw)` is the single entry point for external data
- Validates all fields and collects all errors before failing
- `@rules` macro enables declarative validation rule definitions
- Automatically infers default values and optional fields from struct definitions

# Basic Usage

## Simple Usage (Recommended)

The easiest way to get started is with `@validated_model`, which automatically validates on construction:

```julia
using BoundaryTypes

# Define a validated model
@validated_model struct Signup
    email::String
    password::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end

# Define validation rules
@rules Signup begin
    field(:email, email())
    field(:password, minlen(12), secret())
    field(:age, ge(0), le(150))
    field(:nickname, minlen(3))
end

# Constructor automatically validates - IDE autocomplete works!
signup = Signup(email="user@example.com", password="SecurePass123", age=25)
```

## Advanced Usage

For more control over validation timing, use `@model` with explicit `model_validate`:

```julia
@model struct Config
    host::String
    port::Int
end

@rules Config begin
    field(:host, minlen(1))
    field(:port, ge(1), le(65535))
end

# Explicit validation call
config = model_validate(Config, Dict(:host => "localhost", :port => 8080))

# Safe validation (does not throw)
ok, result = try_model_validate(Config, raw_data)
if ok
    # result::Config
else
    # result::ValidationError
end
```

# Nested Struct Validation

BoundaryTypes.jl automatically validates nested structs that are registered with `@model`:

```julia
@model struct Address
    city::String
    zipcode::String
end

@rules Address begin
    field(:zipcode, regex(r"^\\d{5}\$"))
end

@model struct User
    name::String
    address::Address  # Nested model
end

# Nested validation happens automatically
user = model_validate(User, Dict(
    :name => "Alice",
    :address => Dict(:city => "Tokyo", :zipcode => "12345")
))

# Error paths include nested field names
# e.g., [:address, :zipcode]
```

# Exports

## Macros
- `@model`: Define a validated model
- `@validated_model`: Define a model with automatic constructor validation (recommended)
- `@rules`: Define validation rules for a model

## Validation Functions
- `model_validate`: Validate input (throws on error)
- `try_model_validate`: Safe validation (returns status and result)
- `model_validate_json`: Validate from JSON string (throws on error)
- `try_model_validate_json`: Safe validation from JSON string

## Update Functions
- `model_copy`: Create a new instance with updated field values
- `model_copy!`: Update a mutable struct instance in-place

## Serialization Functions
- `model_dump`: Convert instance to Dict (Symbol or String keys)
- `model_dump_json`: Convert instance to JSON string

## Introspection Functions
- `show_rules`: Display validation rules for a registered model type
- `schema`: Generate JSON Schema (Draft 7) for a model
- `available_rules`: Show all available validation rules
- `string_rules`: Show string validation rules
- `numeric_rules`: Show numeric validation rules
- `collection_rules`: Show collection validation rules
- `show_rule_examples`: Show comprehensive usage examples

## Error Types
- `ValidationError`: Exception type for validation failures
- `FieldError`: Individual field error information

## Validation Rules

### String Rules
- `minlen(n)`: Minimum string/collection length
- `maxlen(n)`: Maximum string/collection length
- `regex(re)`: Regular expression pattern matching
- `email()`: Email address validation
- `url()`: URL format validation
- `uuid()`: UUID format validation
- `choices(values)`: Enum-like validation

### Numeric Rules
- `ge(n)`: Greater than or equal (≥)
- `le(n)`: Less than or equal (≤)
- `gt(n)`: Strictly greater than (>)
- `lt(n)`: Strictly less than (<)
- `between(min, max)`: Range validation (inclusive)
- `multiple_of(n)`: Divisibility check

### Collection Rules
- `each(rule)`: Apply rule to each element

### Other Rules
- `present()`: Require field presence in input
- `notnothing()`: Prohibit `nothing` values
- `secret()`: Mask values in error messages
- `custom(f; code, msg)`: Define custom validation rules

See also: [`@validated_model`](@ref), [`@model`](@ref), [`@rules`](@ref), [`model_validate`](@ref)
"""
module BoundaryTypes

using JSON3

include("core.jl")
include("rules.jl")
include("parse.jl")
include("macros.jl")

export @model, @rules, @validated_model, field,
        model_validate, try_model_validate, model_validate_json, try_model_validate_json,
        model_copy, model_copy!, model_dump, model_dump_json,
        show_rules, schema,
        ValidationError, FieldError,
        minlen, maxlen, regex, ge, le, gt, lt, between, multiple_of,
        email, url, uuid, choices,
        present, notnothing, secret, custom, each,
        available_rules, string_rules, numeric_rules, collection_rules, show_rule_examples
end
