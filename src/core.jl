"""
    FieldError

Represents a validation error for a specific field.

# Fields
- `path::Vector{Symbol}`: Field path (supports nested fields in future)
- `code::Symbol`: Machine-readable error code (e.g., `:minlen`, `:regex`, `:missing`)
- `message::String`: Human-readable error message
- `got::Any`: The actual value that failed validation
- `secret::Bool`: Whether to mask the value in error output

# Example
```julia
FieldError(
    [:password],
    :minlen,
    "string too short",
    "***",  # masked if secret=true
    true
)
```
"""
struct FieldError
    path::Vector{Symbol}
    code::Symbol
    message::String
    got::Any
    secret::Bool
end

"""
    ValidationError <: Exception

Exception thrown when validation fails. Contains all field errors collected during validation.

# Fields
- `errors::Vector{FieldError}`: Collection of all validation errors

# Example
```julia
try
    signup = model_validate(Signup, invalid_data)
catch e::ValidationError
    for err in e.errors
        println("Field: ", err.path, ", Error: ", err.message)
    end
end
```

See also: [`FieldError`](@ref)
"""
struct ValidationError <: Exception
    errors::Vector{FieldError}
end

function Base.showerror(io::IO, e::ValidationError)::Nothing
    println(io, "ValidationError with $(length(e.errors)) error(s):")
    for err in e.errors
        got = err.secret ? "***" : repr(err.got)
        println(io, "  - ", join(string.(err.path), "."),
                " [", err.code, "]: ", err.message,
                " (got=", got, ")")
    end
    return nothing
end

"""
    Rule

Represents a single validation rule.

# Fields
- `code::Symbol`: Machine-readable rule identifier
- `pred::Function`: Predicate function `(value, ctx) -> Bool` that returns true if validation passes
- `msg::Union{Nothing,String}`: Optional custom error message (uses default if `nothing`)

# Example
```julia
Rule(:minlen, (v, ctx) -> length(v) >= 12, "password too short")julia -e 'using Pkg; Pkg.Apps.add(; url="https://github.com/aviatesk/JETLS.jl", rev="release")'
```

See also: [`minlen`](@ref), [`regex`](@ref), [`custom`](@ref)
"""
struct Rule
    code::Symbol
    pred::Function            # (value, ctx) -> Bool
    msg::Union{Nothing,String}
end

"""
    FieldSpec

Internal specification for a model field, inferred from struct definition and `@rules`.

# Fields
- `name::Symbol`: Field name
- `typ::Any`: Field type
- `has_default::Bool`: Whether field has a default value
- `default_expr::Any`: Default value expression
- `is_optional::Bool`: Whether field type is `Union{Nothing,T}`
- `secret::Bool`: Whether to mask field value in error messages
- `rules::Vector{Any}`: Validation rules applied to this field (Rule or EachTag)

# Inference Rules
From struct definition:
- `x::T` → required field
- `x::T = v` → field with default value
- `x::Union{Nothing,T}` → optional field
- `x::Union{Nothing,T} = nothing` → optional with default

See also: [`ModelSpec`](@ref), [`Rule`](@ref)
"""
struct FieldSpec
    name::Symbol
    typ::Any
    has_default::Bool
    default_expr::Any
    is_optional::Bool
    secret::Bool
    rules::Vector{Any}  # Can contain Rule or EachTag
end

"""
    ModelSpec

Internal specification for a validated model type.

# Fields
- `fields::Dict{Symbol,FieldSpec}`: Field specifications indexed by field name
- `extra::Symbol`: How to handle extra fields in input (`:forbid`, `:ignore`, or `:allow`)

Currently, only `:forbid` is implemented, which rejects any fields not defined in the model.

See also: [`FieldSpec`](@ref)
"""
struct ModelSpec
    fields::Dict{Symbol,FieldSpec}
    extra::Symbol            # :forbid | :ignore | :allow
end

const _MODEL_SPECS = IdDict{DataType, ModelSpec}()
const _RULES = IdDict{DataType, Dict{Symbol, Vector{Any}}}()  # Any: Rule or SecretTag

"""
    RuleCtx

Context information passed to validation rule predicates.

# Fields
- `provided::Bool`: Whether the field was present in the raw input
- `defaulted::Bool`: Whether the default value was used
- `optional::Bool`: Whether the field type is optional (`Union{Nothing,T}`)

This context allows rules to behave differently based on how the value was obtained.
For example, `present()` checks `ctx.provided`, and optional fields skip most rules
when the value is `nothing`.

See also: [`Rule`](@ref), [`present`](@ref)
"""
struct RuleCtx
    provided::Bool
    defaulted::Bool
    optional::Bool
end

"""
    _is_optional_type(T)

Internal helper to determine if a type is `Union{Nothing,T}`.

# Arguments
- `T`: Type to check

# Returns
- `Bool`: `true` if `T` is a Union containing `Nothing`, `false` otherwise

# Example
```julia
_is_optional_type(Union{Nothing,String})  # true
_is_optional_type(String)                  # false
```
"""
function _is_optional_type(T::Any)::Bool
    if T isa Union
        return (Nothing in Base.uniontypes(T))
    end
    return false
end
