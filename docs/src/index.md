# BoundaryTypes.jl

A Pydantic-like validation library for Julia that provides comprehensive input validation at system boundaries while maintaining Julia's type safety and philosophy.

## Overview

BoundaryTypes.jl provides a macro-based system for declarative validation of struct fields. It supports:

- Declarative validation rules attached to struct fields
- Comprehensive error collection (all errors reported at once)
- Automatic inference of default values and optional fields
- Two validation approaches: explicit validation or enforced constructor validation

## Quick Start

### Define a Model with Validation Rules

```julia
using BoundaryTypes

# 1. Define a model
@model struct User
    email::String
    password::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end

# 2. Define validation rules
@rules User begin
    field(:email, regex(r"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
    field(:password, minlen(12), secret())
    field(:age, ge(0), le(150))
    field(:nickname, minlen(3))
end

# 3. Validate input
user = model_validate(User, Dict(
    :email => "user@example.com",
    :password => "SecurePass123",
    :age => 25
))
```

### Two Validation Approaches

#### Approach 1: Explicit Validation (Pydantic-like)

```julia
@model struct Signup
    email::String
    password::String
end

@rules Signup begin
    field(:email, regex(r"@"))
    field(:password, minlen(8))
end

# Validate manually at boundaries
signup = model_validate(Signup, raw_input)
```

#### Approach 2: Enforced Validation (Constructor Override)

```julia
@validated_model struct Signup
    email::String
    password::String
end

@rules Signup begin
    field(:email, regex(r"@"))
    field(:password, minlen(8))
end

# Constructor automatically validates
signup = Signup(email="user@example.com", password="secure123")
# Invalid input throws ValidationError automatically
```

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/daikichiba9511/BoundaryTypes.jl")
```

## Features

### Declarative Validation Rules

Attach validation rules to struct fields using the `@rules` macro:

```julia
@rules User begin
    field(:email, regex(r"@"), minlen(5))
    field(:age, ge(0), le(150))
    field(:password, minlen(12), secret())
end
```

### Available Validation Rules

#### String Rules
- `minlen(n)`: Minimum string/collection length
- `maxlen(n)`: Maximum string/collection length
- `regex(pattern)`: Regular expression matching
- `email()`: Email address validation
- `url()`: URL format validation
- `uuid()`: UUID format validation
- `choices(values)`: Enum-like validation

#### Numeric Rules
- `ge(n)`: Greater than or equal (≥)
- `le(n)`: Less than or equal (≤)
- `gt(n)`: Strictly greater than (>)
- `lt(n)`: Strictly less than (<)
- `between(min, max)`: Range validation (inclusive)
- `multiple_of(n)`: Divisibility check

#### Collection Rules
- `each(rule)`: Apply rule to each element in a collection

#### Other Rules
- `present()`: Require field presence in input
- `notnothing()`: Prohibit `nothing` values
- `secret()`: Mask values in error messages
- `custom(f; code, msg)`: Custom validation logic

### Discovering Available Rules

To help discover and learn about available validation rules, BoundaryTypes.jl provides helper functions:

```julia
# Show all available rules
available_rules()

# Show rules by category
string_rules()
numeric_rules()
collection_rules()

# Show comprehensive usage examples
show_rule_examples()
```

These functions display formatted documentation with descriptions, signatures, and examples for each rule.

### Comprehensive Error Reporting

All validation errors are collected and reported together:

```julia
try
    model_validate(User, Dict(:email => "invalid", :age => -5))
catch e
    # e.errors contains ALL field errors:
    # - email: regex validation failed
    # - age: must be >= 0
end
```

### Safe Validation

Use `try_model_validate` for non-throwing validation:

```julia
ok, result = try_model_validate(User, raw_input)
if ok
    # result is User instance
    process(result)
else
    # result is ValidationError
    log_errors(result.errors)
end
```

### Optional Fields and Defaults

```julia
@model struct Profile
    name::String                          # Required
    age::Int = 0                         # Has default
    bio::Union{Nothing,String} = nothing # Optional
end

@rules Profile begin
    field(:name, minlen(1))
    field(:age, ge(0))
    field(:bio, minlen(10))  # Only validated if provided and not nothing
end
```

### Collection Validation

Validate arrays, vectors, and sets using the `each(rule)` combinator:

```julia
@model struct Post
    title::String
    tags::Vector{String}
    scores::Vector{Int}
end

@rules Post begin
    field(:title, minlen(1))
    field(:tags, minlen(1), maxlen(10), each(minlen(3)))
    # At least 1 tag, max 10 tags, each tag must be at least 3 characters

    field(:scores, each(ge(0)), each(le(100)))
    # All scores must be between 0 and 100
end

# Valid
post = model_validate(Post, Dict(
    :title => "My Post",
    :tags => ["julia", "programming"],
    :scores => [85, 90, 95]
))

# Error: second tag too short
model_validate(Post, Dict(
    :title => "My Post",
    :tags => ["julia", "ab"],  # "ab" is too short
    :scores => [85]
))
# => ValidationError: tags[1] [minlen]: too short (got="ab")
```

Supported collection types: `Vector{T}`, `Set{T}`, and any type implementing `AbstractArray` or `AbstractSet`.

## See Also

- [API Reference](api.md) - Complete API documentation
