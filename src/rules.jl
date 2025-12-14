"""
    SecretTag

Internal marker type for the `secret()` attribute.

See also: [`secret`](@ref)
"""
struct SecretTag end

"""
    secret()

Mark a field as containing sensitive data. When validation fails, the field's value
will be masked as `"***"` in error messages to prevent accidental exposure of
passwords, API keys, or other secrets.

This is not a validation rule but an attribute that affects error reporting.

# Example
```julia
@rules User begin
    field(:password, minlen(12), secret())
    field(:api_key, regex(r"^sk-"), secret())
end

# Validation error will show:
#   - password [minlen]: string too short (got=***)
# instead of exposing the actual password
```

See also: [`@rules`](@ref)
"""
secret() = SecretTag()

"""
    present(; msg=nothing)

Require that the field is present in the input data.

By default, optional fields (`Union{Nothing,T}`) do not require presence.
Use this rule to enforce that the field key exists in the input, even if the value is `nothing`.

# Arguments
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Config
    debug::Union{Nothing,Bool} = nothing
end

@rules Config begin
    field(:debug, present())  # Must provide :debug key in input
end

model_validate(Config, Dict())              # Error: missing
model_validate(Config, Dict(:debug => nothing))  # OK
```

See also: [`notnothing`](@ref)
"""
present(; msg=nothing)    = Rule(:present, (v, ctx)->ctx.provided, msg)

"""
    notnothing(; msg=nothing)

Prohibit `nothing` values for optional fields.

For optional fields (`Union{Nothing,T}`), this rule enforces that if the field
is provided, it must not be `nothing`.

# Arguments
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct User
    nickname::Union{Nothing,String} = nothing
end

@rules User begin
    field(:nickname, notnothing())  # If provided, must not be nothing
end

model_validate(User, Dict())                    # OK (uses default)
model_validate(User, Dict(:nickname => nothing)) # Error
model_validate(User, Dict(:nickname => "Alice")) # OK
```

See also: [`present`](@ref)
"""
notnothing(; msg=nothing) = Rule(:notnothing, (v, ctx)->(v !== nothing), msg)

"""
    ge(n; msg=nothing)

Require that a numeric value is greater than or equal to `n`.

# Arguments
- `n`: Minimum value (inclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Product
    price::Float64
    stock::Int
end

@rules Product begin
    field(:price, ge(0.0))  # Non-negative price
    field(:stock, ge(0))    # Non-negative stock
end
```

See also: [`le`](@ref)
"""
ge(n; msg=nothing) = Rule(:ge, (v, ctx)->(v isa Number && v >= n), msg)

"""
    le(n; msg=nothing)

Require that a numeric value is less than or equal to `n`.

# Arguments
- `n`: Maximum value (inclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Person
    age::Int
    satisfaction::Float64
end

@rules Person begin
    field(:age, ge(0), le(150))           # Age between 0-150
    field(:satisfaction, ge(0.0), le(1.0)) # Rating from 0.0 to 1.0
end
```

See also: [`ge`](@ref)
"""
le(n; msg=nothing) = Rule(:le, (v, ctx)->(v isa Number && v <= n), msg)

"""
    minlen(n; msg=nothing)

Require that a string has at least `n` characters.

# Arguments
- `n::Integer`: Minimum length (inclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Account
    username::String
    password::String
end

@rules Account begin
    field(:username, minlen(3))   # At least 3 characters
    field(:password, minlen(12))  # At least 12 characters
end
```

See also: [`regex`](@ref)
"""
minlen(n; msg=nothing) = Rule(:minlen, (v, ctx)->(v isa AbstractString && length(v) >= n), msg)

"""
    regex(re::Regex; msg=nothing)

Require that a string matches the given regular expression.

# Arguments
- `re::Regex`: Regular expression pattern
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Signup
    email::String
    phone::String
end

@rules Signup begin
    field(:email, regex(r"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\$"))
    field(:phone, regex(r"^\\+?[0-9]{10,15}\$"))
end
```

See also: [`minlen`](@ref), [`custom`](@ref)
"""
regex(re::Regex; msg=nothing) = Rule(:regex, (v, ctx)->(v isa AbstractString && occursin(re, v)), msg)

"""
    custom(f; code::Symbol=:custom, msg=nothing)

Define a custom validation rule with an arbitrary predicate function.

# Arguments
- `f::Function`: Predicate function `(value) -> Bool` that returns `true` if validation passes
- `code::Symbol`: Machine-readable error code (default: `:custom`)
- `msg::Union{Nothing,String}`: Error message when validation fails (optional)

# Example
```julia
@model struct Event
    attendees::Int
    date::String
end

@rules Event begin
    field(:attendees, custom(x -> x % 2 == 0; code=:even, msg="must be even"))
    field(:date, custom(x -> occursin(r"^\\d{4}-\\d{2}-\\d{2}\$", x);
                        code=:date_format, msg="must be YYYY-MM-DD"))
end
```

Note: The predicate receives only the value, not the context. For context-aware rules,
create a `Rule` directly.

See also: [`Rule`](@ref)
"""
custom(f; code::Symbol=:custom, msg=nothing) = Rule(code, (v, ctx)->Bool(f(v)), msg)

"""
    default_msg(r::Rule)

Return the default error message for a built-in rule code.

# Arguments
- `r::Rule`: The rule to get the default message for

# Returns
- `String`: Default error message corresponding to the rule's code

This function is used internally when a rule does not provide a custom message.
"""
function default_msg(r::Rule)
    r.code === :minlen     && return "string too short"
    r.code === :regex      && return "does not match required pattern"
    r.code === :ge         && return "must satisfy >= constraint"
    r.code === :le         && return "must satisfy <= constraint"
    r.code === :present    && return "field must be present"
    r.code === :notnothing && return "must not be nothing"
    return "validation failed"
end
