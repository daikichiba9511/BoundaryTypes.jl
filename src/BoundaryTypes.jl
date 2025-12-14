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

```julia
using BoundaryTypes

# Define a model
@model struct Signup
    email::String
    password::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end

# Define validation rules
@rules Signup begin
    field(:email, regex(r"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\$"))
    field(:password, minlen(12), secret())
    field(:age, ge(0), le(150))
    field(:nickname, minlen(3))
end

# Validate input
signup = model_validate(Signup, Dict(:email => "user@example.com",
                                      :password => "SecurePass123"))

# Safe validation (does not throw)
ok, result = try_model_validate(Signup, raw_data)
if ok
    # result::Signup
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
- `@rules`: Define validation rules for a model

## Validation Functions
- `model_validate`: Validate input (throws on error)
- `try_model_validate`: Safe validation (returns status and result)
- `model_validate_json`: Validate from JSON string (throws on error)
- `try_model_validate_json`: Safe validation from JSON string

## Update Functions
- `model_copy`: Create a new instance with updated field values
- `model_copy!`: Update a mutable struct instance in-place

## Introspection Functions
- `show_rules`: Display validation rules for a registered model type

## Error Types
- `ValidationError`: Exception type for validation failures
- `FieldError`: Individual field error information

## Validation Rules
- `minlen(n)`: Minimum string length
- `regex(re)`: Regular expression pattern matching
- `ge(n)`: Greater than or equal constraint
- `le(n)`: Less than or equal constraint
- `present()`: Require field presence in input
- `notnothing()`: Prohibit `nothing` values
- `secret()`: Mask values in error messages
- `custom(f; code, msg)`: Define custom validation rules

See also: [`@model`](@ref), [`@rules`](@ref), [`model_validate`](@ref)
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
        minlen, regex, ge, le,
        present, notnothing, secret, custom
end
