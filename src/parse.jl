"""
    normalize(raw)::Dict{Symbol,Any}

Normalize various input formats into a standardized `Dict{Symbol,Any}` format.

# Arguments
- `raw`: Input data (Dict, NamedTuple, or keyword arguments)

# Returns
- `Dict{Symbol,Any}`: Normalized dictionary with Symbol keys

# Supported Input Types
- `Dict{Symbol,Any}`: Returned as-is
- `Dict{String,Any}` or other Dict types: Keys converted to Symbols
- `NamedTuple`: Converted to Dict with Symbol keys
- `Base.Pairs` (keyword arguments): Converted to Dict with Symbol keys

# Throws
- `ArgumentError`: If input type is not supported

# Example
```julia
normalize(Dict("email" => "a@b.com"))  # Dict(:email => "a@b.com")
normalize((email="a@b.com",))          # Dict(:email => "a@b.com")
```
"""
function normalize(raw)::Dict{Symbol,Any}
    if raw isa Dict{Symbol,Any}
        return raw
    elseif raw isa Dict
        d = Dict{Symbol,Any}()
        for (k,v) in raw
            d[k isa Symbol ? k : Symbol(k)] = v
        end
        return d
    elseif raw isa NamedTuple
        return Dict{Symbol,Any}(pairs(raw))
    elseif raw isa Base.Pairs
        # Handle keyword arguments (Base.Pairs)
        d = Dict{Symbol,Any}()
        for (k,v) in pairs(raw)
            d[k isa Symbol ? k : Symbol(k)] = v
        end
        return d
    else
        throw(ArgumentError("Unsupported input type: $(typeof(raw))"))
    end
end

"""
    coerce(::Type{T}, x; strict::Bool=true) where T

Attempt to coerce a value to the target type.

# Arguments
- `T::Type`: Target type
- `x`: Value to coerce
- `strict::Bool`: If true, only accept exact type matches (default: true)

# Returns
- `Tuple{Union{T,Nothing}, Union{String,Nothing}}`: (coerced_value, error_message)
  - Success: `(value::T, nothing)`
  - Failure: `(nothing, error_message::String)`

# Current Implementation

Currently, only strict type checking is implemented. Future extensions will support
automatic coercion (e.g., `"123"` → `123` for Int fields).

# Example
```julia
coerce(Int, 42)      # (42, nothing)
coerce(Int, "42")    # (nothing, "expected Int64, got String")
```
"""
function coerce(::Type{T}, x; strict::Bool=true) where T
    if strict
        return (x isa T) ? (x, nothing) : (nothing, "expected $(T), got $(typeof(x))")
    else
        # ここは後で拡張（"123"→Int 等）
        return (x isa T) ? (x, nothing) : (nothing, "expected $(T), got $(typeof(x))")
    end
end

"""
    mask_if_secret(value, secret::Bool)

Mask a value with `"***"` if it is marked as secret.

# Arguments
- `value`: The value to potentially mask
- `secret::Bool`: Whether the value should be masked

# Returns
- `"***"` if `secret` is true, otherwise the original value

This is used internally to prevent sensitive data (passwords, API keys) from
appearing in error messages.
"""
function mask_if_secret(value, secret::Bool)
    return secret ? "***" : value
end

"""
    _is_registered_model(T)

Internal helper to check if a type is registered as a model.

# Arguments
- `T`: Type to check

# Returns
- `Bool`: `true` if `T` is registered in `_MODEL_SPECS`, `false` otherwise
"""
function _is_registered_model(T)
    return haskey(_MODEL_SPECS, T)
end

"""
    _validate_nested!(errors::Vector{FieldError}, field_name::Symbol, field_type::Type, raw_value, path_prefix::Vector{Symbol}, strict::Bool, extra::Symbol)

Recursively validate a nested model field.

# Arguments
- `errors::Vector{FieldError}`: Error accumulator (mutated)
- `field_name::Symbol`: Name of the field being validated
- `field_type::Type`: Type of the nested model
- `raw_value`: Raw input value for the nested model
- `path_prefix::Vector{Symbol}`: Path prefix for nested fields
- `strict::Bool`: Strict type checking flag
- `extra::Symbol`: How to handle extra fields

# Returns
- `Union{Any,Nothing}`: Validated nested instance, or `nothing` if validation failed

# Side Effects
Appends validation errors to the `errors` vector with proper path prefixes.
"""
function _validate_nested!(errors::Vector{FieldError}, field_name::Symbol, field_type::Type, raw_value, path_prefix::Vector{Symbol}, strict::Bool, extra::Symbol)
    # Normalize the raw value to Dict format
    nested_input = try
        normalize(raw_value)
    catch e
        # If normalization fails, it's a type error
        push!(errors, FieldError(vcat(path_prefix, [field_name]), :type,
                                "expected Dict/NamedTuple for nested model, got $(typeof(raw_value))",
                                raw_value, false))
        return nothing
    end

    # Recursively validate the nested model
    nested_spec = _MODEL_SPECS[field_type]
    nested_errors = FieldError[]

    # Check for extra fields in nested model
    if extra == :forbid
        allowed = Set(keys(nested_spec.fields))
        for k in keys(nested_input)
            if !(k in allowed)
                full_path = vcat(path_prefix, [field_name, k])
                push!(nested_errors, FieldError(full_path, :extra, "extra field", nested_input[k], false))
            end
        end
    end

    nested_values = Dict{Symbol,Any}()
    current_path = vcat(path_prefix, [field_name])

    # Validate each field of the nested model
    for (nested_name, nested_fs) in nested_spec.fields
        nested_provided = haskey(nested_input, nested_name)

        if !nested_provided
            if nested_fs.has_default
                v = nested_fs.default_expr
                nested_values[nested_name] = v
                apply_rules!(nested_errors, nested_fs, v, RuleCtx(false, true, nested_fs.is_optional), current_path)
            else
                if nested_fs.is_optional
                    nested_values[nested_name] = nothing
                else
                    push!(nested_errors, FieldError(vcat(current_path, [nested_name]), :missing, "missing", nothing, nested_fs.secret))
                end
            end
            continue
        end

        nested_rawv = nested_input[nested_name]

        if nested_fs.is_optional && nested_rawv === nothing
            nested_values[nested_name] = nothing
            apply_rules!(nested_errors, nested_fs, nothing, RuleCtx(true, false, true), current_path)
            continue
        end

        # Check if this field is also a nested model
        # Extract actual type if it's optional (Union{Nothing,T})
        nested_actual_type = nested_fs.typ
        if nested_fs.is_optional
            types = Base.uniontypes(nested_fs.typ)
            non_nothing = filter(t -> t !== Nothing, types)
            if length(non_nothing) == 1
                nested_actual_type = non_nothing[1]
            end
        end

        if _is_registered_model(nested_actual_type)
            nested_instance = _validate_nested!(nested_errors, nested_name, nested_actual_type, nested_rawv, current_path, strict, extra)
            if nested_instance !== nothing
                nested_values[nested_name] = nested_instance
                apply_rules!(nested_errors, nested_fs, nested_instance, RuleCtx(true, false, nested_fs.is_optional), current_path)
            end
        else
            # Regular field validation
            v, err = coerce(nested_fs.typ, nested_rawv; strict=strict)
            if err !== nothing
                masked_value = mask_if_secret(nested_rawv, nested_fs.secret)
                push!(nested_errors, FieldError(vcat(current_path, [nested_name]), :type, err, masked_value, nested_fs.secret))
                continue
            end

            nested_values[nested_name] = v
            apply_rules!(nested_errors, nested_fs, v, RuleCtx(true, false, nested_fs.is_optional), current_path)
        end
    end

    # Add nested errors to the main error list
    append!(errors, nested_errors)

    # If there were any errors, return nothing
    if !isempty(nested_errors)
        return nothing
    end

    # Fill in optional missing values
    for n in fieldnames(field_type)
        if !haskey(nested_values, n)
            nested_values[n] = nothing
        end
    end

    # Construct the nested instance
    return construct(field_type, nested_values)
end

"""
    apply_rules!(errors::Vector{FieldError}, fs::FieldSpec, value, ctx::RuleCtx, path_prefix::Vector{Symbol}=Symbol[])

Apply all validation rules for a field and collect any errors.

# Arguments
- `errors::Vector{FieldError}`: Error accumulator (mutated)
- `fs::FieldSpec`: Field specification containing rules
- `value`: The value to validate
- `ctx::RuleCtx`: Validation context (provided, defaulted, optional)
- `path_prefix::Vector{Symbol}`: Path prefix for nested fields (default: empty)

# Behavior

- For optional fields with `nothing` values, most rules are skipped except
  `present()` and `notnothing()`
- Rule predicates are executed with error handling (exceptions count as failures)
- Failed rules append `FieldError` entries to the errors vector
- Secret fields have their values masked in error messages

# Side Effects
Mutates the `errors` vector by appending validation failures.
"""
function apply_rules!(errors::Vector{FieldError}, fs::FieldSpec, value, ctx::RuleCtx, path_prefix::Vector{Symbol}=Symbol[])
    for r in fs.rules
        # optional & nothing のときは present/notnothing 以外スキップ
        if ctx.optional && value === nothing
            if !(r.code in (:present, :notnothing))
                continue
            end
        end

        ok = false
        try
            ok = r.pred(value, ctx)
        catch
            ok = false
        end

        if !ok
            msg = something(r.msg, default_msg(r))
            masked_value = mask_if_secret(value, fs.secret)
            full_path = vcat(path_prefix, [fs.name])
            push!(errors, FieldError(full_path, r.code, msg, masked_value, fs.secret))
        end
    end
end

"""
    construct(::Type{T}, values::Dict{Symbol,Any}) where T

Construct an instance of type `T` from validated field values.

# Arguments
- `T::Type`: The type to construct
- `values::Dict{Symbol,Any}`: Validated field values indexed by field name

# Returns
- `T`: Constructed instance

This function is called internally after all validation passes to create the
final validated instance.

# Example
```julia
values = Dict(:email => "user@example.com", :password => "SecurePass123")
user = construct(User, values)
```
"""
function construct(::Type{T}, values::Dict{Symbol,Any}) where T
    args = Any[ values[n] for n in fieldnames(T) ]
    return T(args...)
end

"""
    model_validate(::Type{T}, raw; strict::Bool=true, extra::Symbol=:forbid) where T

Validate raw input against a model type and construct a validated instance.

# Arguments
- `T::Type`: Model type (must be registered with `@model`)
- `raw`: Raw input data (Dict, NamedTuple, or keyword arguments)
- `strict::Bool`: If true, enforce strict type matching (default: true)
- `extra::Symbol`: How to handle extra fields - `:forbid` (reject), `:ignore`, or `:allow` (default: `:forbid`)

# Returns
- `T`: Validated and constructed instance

# Throws
- `ValidationError`: If any validation rules fail
- `ArgumentError`: If `T` is not registered with `@model`

# Validation Process

1. Normalize input to `Dict{Symbol,Any}`
2. Check for extra fields (if `extra == :forbid`)
3. For each field:
   - If missing and has default: use default value
   - If missing and required: error
   - If missing and optional: use `nothing`
   - If present: coerce to target type and validate rules
4. Collect all errors before failing
5. If validation passes, construct instance

# Example
```julia
@model struct User
    email::String
    age::Int = 0
end

@rules User begin
    field(:email, regex(r"@"))
    field(:age, ge(0))
end

user = model_validate(User, Dict(:email => "user@example.com"))
# => User("user@example.com", 0)

model_validate(User, Dict(:email => "invalid"))
# => ValidationError: email [regex]: does not match required pattern
```

See also: [`try_model_validate`](@ref), [`@model`](@ref), [`@rules`](@ref)
"""
function model_validate(::Type{T}, raw; strict::Bool=true, extra::Symbol=:forbid) where T
    input = normalize(raw)
    spec = get(_MODEL_SPECS, T, nothing)
    spec === nothing && throw(ArgumentError("No model spec registered for $(T). Use @model."))

    errors = FieldError[]
    if extra == :forbid
        allowed = Set(keys(spec.fields))
        for k in keys(input)
            if !(k in allowed)
                push!(errors, FieldError([k], :extra, "extra field", input[k], false))
            end
        end
    end

    values = Dict{Symbol,Any}()

    for (name, fs) in spec.fields
        provided = haskey(input, name)

        if !provided
            if fs.has_default
                v = fs.default_expr
                values[name] = v
                # For optional fields with nothing default, skip validation except present/notnothing
                apply_rules!(errors, fs, v, RuleCtx(false, true, fs.is_optional))
            else
                if fs.is_optional
                    values[name] = nothing
                    # No rules applied for optional fields without default and not provided
                else
                    push!(errors, FieldError([name], :missing, "missing", nothing, fs.secret))
                end
            end
            continue
        end

        rawv = input[name]

        if fs.is_optional && rawv === nothing
            values[name] = nothing
            apply_rules!(errors, fs, nothing, RuleCtx(true, false, true))
            continue
        end

        # Check if this field is a nested model
        # Extract actual type if it's optional (Union{Nothing,T})
        actual_type = fs.typ
        if fs.is_optional
            types = Base.uniontypes(fs.typ)
            non_nothing = filter(t -> t !== Nothing, types)
            if length(non_nothing) == 1
                actual_type = non_nothing[1]
            end
        end

        if _is_registered_model(actual_type)
            nested_instance = _validate_nested!(errors, name, actual_type, rawv, Symbol[], strict, extra)
            if nested_instance !== nothing
                values[name] = nested_instance
                apply_rules!(errors, fs, nested_instance, RuleCtx(true, false, fs.is_optional))
            end
            continue
        end

        v, err = coerce(fs.typ, rawv; strict=strict)
        if err !== nothing
            masked_value = mask_if_secret(rawv, fs.secret)
            push!(errors, FieldError([name], :type, err, masked_value, fs.secret))
            continue
        end

        values[name] = v
        apply_rules!(errors, fs, v, RuleCtx(true, false, fs.is_optional))
    end

    isempty(errors) || throw(ValidationError(errors))

    # optional missing を埋める（construct 用）
    for n in fieldnames(T)
        if !haskey(values, n)
            values[n] = nothing
        end
    end

    return construct(T, values)
end

"""
    try_model_validate(::Type{T}, raw; kwargs...) where T

Safely validate input without throwing exceptions.

# Arguments
- `T::Type`: Model type (must be registered with `@model`)
- `raw`: Raw input data (Dict, NamedTuple, or keyword arguments)
- `kwargs...`: Additional arguments passed to `model_validate`

# Returns
- `Tuple{Bool, Union{T, ValidationError}}`:
  - Success: `(true, instance::T)`
  - Failure: `(false, error::ValidationError)`

# Example
```julia
ok, result = try_model_validate(User, Dict(:email => "user@example.com"))
if ok
    println("Valid user: ", result.email)
else
    println("Validation failed:")
    for err in result.errors
        println("  - ", err.message)
    end
end
```

This is the recommended way to validate input in production code, as it provides
explicit error handling without exceptions.

See also: [`model_validate`](@ref), [`ValidationError`](@ref)
"""
function try_model_validate(::Type{T}, raw; kwargs...) where T
    try
        return true, model_validate(T, raw; kwargs...)
    catch e
        if e isa ValidationError
            return false, e
        end
        rethrow()
    end
end

"""
    model_validate_json(::Type{T}, json_str::AbstractString; kwargs...) where T

Parse and validate a JSON string against a model type.

# Arguments
- `T::Type`: Model type (must be registered with `@model`)
- `json_str::AbstractString`: JSON string to parse and validate
- `kwargs...`: Additional arguments passed to `model_validate`

# Returns
- `T`: Validated and constructed instance

# Throws
- `ValidationError`: If validation fails
- JSON parsing errors from JSON3

# Example
```julia
@model struct Config
    host::String
    port::Int
end

json_str = "{\\\"host\\\": \\\"localhost\\\", \\\"port\\\": 8080}"
config = model_validate_json(Config, json_str)
# => Config("localhost", 8080)
```

See also: [`try_model_validate_json`](@ref), [`model_validate`](@ref)
"""
function model_validate_json(::Type{T}, json_str::AbstractString; kwargs...) where T
    parsed = JSON3.read(json_str, Dict{String,Any})
    return model_validate(T, parsed; kwargs...)
end

"""
    try_model_validate_json(::Type{T}, json_str::AbstractString; kwargs...) where T

Safely parse and validate a JSON string without throwing exceptions on validation errors.

# Arguments
- `T::Type`: Model type (must be registered with `@model`)
- `json_str::AbstractString`: JSON string to parse and validate
- `kwargs...`: Additional arguments passed to `model_validate`

# Returns
- `Tuple{Bool, Union{T, ValidationError}}`:
  - Success: `(true, instance::T)`
  - Failure: `(false, error::ValidationError)`

# Note
JSON parsing errors are still thrown. Only validation errors are caught and returned.

# Example
```julia
json_str = "{\\\"host\\\": \\\"localhost\\\", \\\"port\\\": \\\"invalid\\\"}"
ok, result = try_model_validate_json(Config, json_str)
if !ok
    println("Validation errors:")
    for err in result.errors
        println("  ", err.path, ": ", err.message)
    end
end
```

See also: [`model_validate_json`](@ref), [`try_model_validate`](@ref)
"""
function try_model_validate_json(::Type{T}, json_str::AbstractString; kwargs...) where T
    try
        parsed = JSON3.read(json_str, Dict{String,Any})
        return true, model_validate(T, parsed; kwargs...)
    catch e
        if e isa ValidationError
            return false, e
        end
        rethrow()
    end
end

"""
    model_copy(instance::T, updates; validate::Bool=true) where T

Create a new instance with updated field values.

Since Julia structs are immutable by default, this function creates a new instance
with specified fields updated while preserving other field values.

# Arguments
- `instance::T`: The original instance to copy
- `updates`: Field updates (Dict, NamedTuple, or keyword arguments)
- `validate::Bool`: Whether to validate the updated values (default: true)

# Returns
- `T`: New instance with updated fields

# Throws
- `ValidationError`: If validation is enabled and updated values fail validation
- `ArgumentError`: If the type is not registered with `@model`

# Example
```julia
@model struct User
    name::String
    email::String
    age::Int = 0
end

@rules User begin
    field(:email, regex(r"@"))
    field(:age, ge(0))
end

user = model_validate(User, Dict(:name => "Alice", :email => "alice@example.com"))

# Update email
updated = model_copy(user, Dict(:email => "newemail@example.com"))
# => User("Alice", "newemail@example.com", 0)

# Multiple updates
updated2 = model_copy(user, Dict(:name => "Bob", :age => 30))
# => User("Bob", "alice@example.com", 30)
```

# Notes
- For immutable structs, this is the only way to update fields
- For mutable structs, consider using `model_copy!` for in-place updates
- Validation ensures the updated instance remains valid

See also: [`model_copy!`](@ref), [`model_validate`](@ref)
"""
function model_copy(instance::T, updates; validate::Bool=true) where T
    # Get current field values
    current_values = Dict{Symbol,Any}()
    for fname in fieldnames(T)
        current_values[fname] = getfield(instance, fname)
    end

    # Merge with updates
    update_dict = normalize(updates)
    merged = merge(current_values, update_dict)

    # Validate or construct directly
    if validate
        return model_validate(T, merged)
    else
        spec = get(_MODEL_SPECS, T, nothing)
        spec === nothing && throw(ArgumentError("No model spec registered for $(T). Use @model."))
        return construct(T, merged)
    end
end

"""
    model_copy!(instance::T, updates; validate::Bool=true) where T

Update a mutable struct instance in-place with new field values.

This function only works with mutable structs. For immutable structs, use `model_copy` instead.

# Arguments
- `instance::T`: The mutable instance to update in-place
- `updates`: Field updates (Dict, NamedTuple, or keyword arguments)
- `validate::Bool`: Whether to validate the updated values (default: true)

# Returns
- `T`: The same instance (mutated)

# Throws
- `ValidationError`: If validation is enabled and updated values fail validation
- `ArgumentError`: If the type is not registered with `@model` or is immutable
- `ErrorException`: If attempting to update an immutable struct

# Example
```julia
@model mutable struct MutableUser
    name::String
    email::String
    age::Int
end

@rules MutableUser begin
    field(:email, regex(r"@"))
    field(:age, ge(0))
end

user = model_validate(MutableUser, Dict(:name => "Alice",
                                         :email => "alice@example.com",
                                         :age => 25))

# Update in-place
model_copy!(user, Dict(:age => 26))
# user.age is now 26

# Multiple updates
model_copy!(user, Dict(:name => "Alicia", :email => "alicia@example.com"))
```

# Notes
- Only works with mutable structs (defined with `mutable struct`)
- Validates updates before applying them (if `validate=true`)
- Returns the same instance for method chaining
- More efficient than `model_copy` for mutable structs

See also: [`model_copy`](@ref), [`model_validate`](@ref)
"""
function model_copy!(instance::T, updates; validate::Bool=true) where T
    # Check if type is mutable
    if !ismutabletype(T)
        throw(ErrorException("model_copy! only works with mutable structs. Use model_copy for immutable structs."))
    end

    spec = get(_MODEL_SPECS, T, nothing)
    spec === nothing && throw(ArgumentError("No model spec registered for $(T). Use @model."))

    # Normalize updates
    update_dict = normalize(updates)

    if validate
        # Validate each update before applying
        errors = FieldError[]
        validated_updates = Dict{Symbol,Any}()

        for (name, new_value) in update_dict
            if !haskey(spec.fields, name)
                push!(errors, FieldError([name], :extra, "field not in model", new_value, false))
                continue
            end

            fs = spec.fields[name]

            # Type coercion
            v, err = coerce(fs.typ, new_value; strict=true)
            if err !== nothing
                masked_value = mask_if_secret(new_value, fs.secret)
                push!(errors, FieldError([name], :type, err, masked_value, fs.secret))
                continue
            end

            # Apply validation rules
            ctx = RuleCtx(true, false, fs.is_optional)
            apply_rules!(errors, fs, v, ctx)

            if isempty(errors)
                validated_updates[name] = v
            end
        end

        isempty(errors) || throw(ValidationError(errors))

        # Apply validated updates
        for (name, value) in validated_updates
            setfield!(instance, name, value)
        end
    else
        # Apply updates without validation
        for (name, value) in update_dict
            if haskey(spec.fields, name)
                setfield!(instance, name, value)
            end
        end
    end

    return instance
end

"""
    show_rules(::Type{T}) where T
    show_rules(io::IO, ::Type{T}) where T

Display the validation rules registered for a model type in a readable format.

# Arguments
- `io::IO`: Output stream (defaults to `stdout`)
- `T::Type`: Model type registered with `@model` or `@validated_model`

# Output Format
Shows the model name, field types, and all validation rules in a structured format:
- Required fields are marked
- Optional fields show `Union{Nothing,T}` type
- Fields with defaults show the default value
- Each validation rule is listed with its parameters
- Secret fields are marked

# Example
```julia
@model struct User
    email::String
    password::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end

@rules User begin
    field(:email, regex(r"@"))
    field(:password, minlen(12), secret())
    field(:age, ge(0), le(150))
end

show_rules(User)
# Output:
# Model: User
#
# Fields:
#   email: String (required)
#     - regex: r"@"
#
#   password: String (required, secret)
#     - minlen: 12
#
#   age: Int64 (default: 0)
#     - ge: 0
#     - le: 150
#
#   nickname: Union{Nothing, String} (optional, default: nothing)
```

See also: [`@model`](@ref), [`@rules`](@ref)
"""
function show_rules(io::IO, ::Type{T}) where T
    spec = get(_MODEL_SPECS, T, nothing)
    if spec === nothing
        println(io, "No rules registered for type $T")
        println(io, "Use @model or @validated_model to register this type.")
        return
    end

    println(io, "Model: $T")
    println(io)
    println(io, "Fields:")

    # Sort fields by name for consistent output
    sorted_fields = sort(collect(spec.fields), by=first)

    for (fname, fspec) in sorted_fields
        # Field name and type
        print(io, "  ", fname, ": ", fspec.typ)

        # Field attributes
        attrs = String[]
        if !fspec.has_default && !fspec.is_optional
            push!(attrs, "required")
        end
        if fspec.is_optional
            push!(attrs, "optional")
        end
        if fspec.has_default
            default_str = if fspec.default_expr === nothing
                "nothing"
            else
                repr(fspec.default_expr)
            end
            push!(attrs, "default: $default_str")
        end
        if fspec.secret
            push!(attrs, "secret")
        end

        if !isempty(attrs)
            print(io, " (", join(attrs, ", "), ")")
        end
        println(io)

        # Rules
        if !isempty(fspec.rules)
            for rule in fspec.rules
                print(io, "    - ", rule.code)

                # Try to extract rule parameters from the predicate
                rule_param = _extract_rule_param(rule)
                if rule_param !== nothing
                    print(io, ": ", rule_param)
                end

                # Show custom message if provided
                if rule.msg !== nothing
                    print(io, " (msg: \"", rule.msg, "\")")
                end

                println(io)
            end
        else
            println(io, "    (no validation rules)")
        end
        println(io)
    end

    # Show extra field handling
    println(io, "Extra fields: ", spec.extra)
end

# Default to stdout
show_rules(::Type{T}) where T = show_rules(stdout, T)

"""
    _extract_rule_param(rule::Rule)

Internal helper to extract parameter information from common rule types.
Returns a string representation of the rule's parameter, or `nothing` if unknown.
"""
function _extract_rule_param(rule::Rule)
    # For common built-in rules, we can't easily extract the parameters
    # from the closure without reflection tricks. Instead, we document them.
    # This is a best-effort display helper.

    # Try to extract info by testing the predicate with sample values
    code = rule.code

    if code == :minlen
        # Test with increasing lengths to find the threshold
        for n in 1:100
            test_str = "a"^n
            try
                if rule.pred(test_str, RuleCtx(true, false, false))
                    return string(n)
                end
            catch
                continue
            end
        end
    elseif code == :ge
        # Try to find the minimum value
        # This is tricky without knowing the actual parameter
        return "(see rule definition)"
    elseif code == :le
        # Try to find the maximum value
        return "(see rule definition)"
    elseif code == :regex
        # Can't easily extract the regex pattern
        return "(see rule definition)"
    elseif code == :present || code == :notnothing
        return ""  # No parameters
    end

    return nothing
end

"""
    _julia_type_to_json_schema_type(T)

Convert Julia type to JSON Schema type string.

# Arguments
- `T`: Julia type

# Returns
- `String`: JSON Schema type ("string", "integer", "number", "boolean", "null", "object", "array")
"""
function _julia_type_to_json_schema_type(T)
    # Handle Union{Nothing,T} - extract the non-Nothing type
    if _is_optional_type(T)
        types = Base.uniontypes(T)
        non_nothing = filter(t -> t !== Nothing, types)
        if length(non_nothing) == 1
            T = non_nothing[1]
        end
    end

    if T === String || T === AbstractString
        return "string"
    elseif T === Int || T === Int64 || T === Int32 || T === Int16 || T === Int8
        return "integer"
    elseif T === Float64 || T === Float32 || T === Number
        return "number"
    elseif T === Bool
        return "boolean"
    elseif T === Nothing
        return "null"
    else
        # For complex types, default to object
        return "object"
    end
end

"""
    _extract_minlen_value(rule::Rule)

Extract the minlen value from a minlen rule by testing the predicate.

# Arguments
- `rule::Rule`: The rule to extract from

# Returns
- `Union{Int,Nothing}`: The minimum length value, or `nothing` if not found
"""
function _extract_minlen_value(rule::Rule)
    rule.code != :minlen && return nothing

    # Binary search for the minimum length
    for n in 1:1000
        test_str = "a"^n
        try
            if rule.pred(test_str, RuleCtx(true, false, false))
                return n
            end
        catch
            continue
        end
    end
    return nothing
end

"""
    _extract_ge_value(rule::Rule)

Extract the minimum value from a ge (greater than or equal) rule by testing the predicate.

# Arguments
- `rule::Rule`: The rule to extract from

# Returns
- `Union{Number,Nothing}`: The minimum value, or `nothing` if not found
"""
function _extract_ge_value(rule::Rule)
    rule.code != :ge && return nothing

    # Try common values
    test_values = [-1000, -100, -10, -1, 0, 1, 10, 100, 1000]
    for v in test_values
        try
            if rule.pred(v, RuleCtx(true, false, false))
                # Found a passing value, now search backwards
                for test_v in reverse(test_values)
                    if test_v > v
                        continue
                    end
                    try
                        if !rule.pred(test_v - 1, RuleCtx(true, false, false))
                            return test_v
                        end
                    catch
                        continue
                    end
                end
                return v
            end
        catch
            continue
        end
    end
    return nothing
end

"""
    _extract_le_value(rule::Rule)

Extract the maximum value from a le (less than or equal) rule by testing the predicate.

# Arguments
- `rule::Rule`: The rule to extract from

# Returns
- `Union{Number,Nothing}`: The maximum value, or `nothing` if not found
"""
function _extract_le_value(rule::Rule)
    rule.code != :le && return nothing

    # Try common values
    test_values = [0, 1, 10, 100, 150, 200, 1000, 10000]
    for v in test_values
        try
            if rule.pred(v, RuleCtx(true, false, false))
                # Found a passing value, now search forwards
                for test_v in test_values
                    if test_v < v
                        continue
                    end
                    try
                        if !rule.pred(test_v + 1, RuleCtx(true, false, false))
                            return test_v
                        end
                    catch
                        continue
                    end
                end
                return v
            end
        catch
            continue
        end
    end
    return nothing
end

"""
    _extract_regex_pattern(rule::Rule)

Extract the regex pattern from a regex rule by inspecting the predicate.

# Arguments
- `rule::Rule`: The rule to extract from

# Returns
- `Union{String,Nothing}`: The regex pattern as a string, or `nothing` if not extractable

# Note
This is a best-effort extraction. Due to Julia's closure implementation,
we cannot directly extract the Regex object from the predicate function.
"""
function _extract_regex_pattern(rule::Rule)
    rule.code != :regex && return nothing

    # Unfortunately, we cannot easily extract the Regex from the closure
    # without using internals. Return nothing for now.
    return nothing
end

"""
    schema(::Type{T}) where T -> Dict{String,Any}

Generate a JSON Schema representation of a validated model type.

# Arguments
- `T::Type`: Model type registered with `@model` or `@validated_model`

# Returns
- `Dict{String,Any}`: JSON Schema object conforming to JSON Schema Draft 7

# Throws
- `ArgumentError`: If `T` is not registered with `@model`

# JSON Schema Mapping

## Field Types
- `String` → `{"type": "string"}`
- `Int`, `Int64`, etc. → `{"type": "integer"}`
- `Float64`, `Float32` → `{"type": "number"}`
- `Bool` → `{"type": "boolean"}`
- `Union{Nothing,T}` → `{"type": [...], "nullable": true}` or included in required fields

## Validation Rules
- `minlen(n)` → `{"minLength": n}`
- `ge(n)` → `{"minimum": n}`
- `le(n)` → `{"maximum": n}`
- `regex(r)` → `{"pattern": "..."}` (best effort)

## Field Properties
- Required fields (no default, not optional) → included in `"required"` array
- Fields with defaults → `"default"` property set
- Optional fields (`Union{Nothing,T}`) → not included in `"required"`

# Example

```julia
@model struct User
    email::String
    password::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end

@rules User begin
    field(:email, regex(r"@"))
    field(:password, minlen(12))
    field(:age, ge(0), le(150))
    field(:nickname, minlen(3))
end

json_schema = schema(User)
# Returns:
# {
#   "\$schema": "http://json-schema.org/draft-07/schema#",
#   "type": "object",
#   "properties": {
#     "email": {"type": "string"},
#     "password": {"type": "string", "minLength": 12},
#     "age": {"type": "integer", "minimum": 0, "maximum": 150, "default": 0},
#     "nickname": {"type": "string", "minLength": 3}
#   },
#   "required": ["email", "password"],
#   "additionalProperties": false
# }
```

See also: [`@model`](@ref), [`@rules`](@ref), [`show_rules`](@ref)
"""
function schema(::Type{T}) where T
    spec = get(_MODEL_SPECS, T, nothing)
    spec === nothing && throw(ArgumentError("No model spec registered for $(T). Use @model."))

    properties = Dict{String,Any}()
    required = String[]

    for (fname, fspec) in spec.fields
        field_schema = Dict{String,Any}()

        # Set JSON Schema type
        json_type = _julia_type_to_json_schema_type(fspec.typ)
        field_schema["type"] = json_type

        # Process validation rules
        for rule in fspec.rules
            if rule.code == :minlen
                min_val = _extract_minlen_value(rule)
                if min_val !== nothing
                    field_schema["minLength"] = min_val
                end
            elseif rule.code == :ge
                min_val = _extract_ge_value(rule)
                if min_val !== nothing
                    field_schema["minimum"] = min_val
                end
            elseif rule.code == :le
                max_val = _extract_le_value(rule)
                if max_val !== nothing
                    field_schema["maximum"] = max_val
                end
            elseif rule.code == :regex
                pattern = _extract_regex_pattern(rule)
                if pattern !== nothing
                    field_schema["pattern"] = pattern
                end
            end
            # Skip :present, :notnothing, :custom, :secret as they don't have direct JSON Schema equivalents
        end

        # Add default value if present
        if fspec.has_default && fspec.default_expr !== nothing
            field_schema["default"] = fspec.default_expr
        end

        # Add description for secret fields
        if fspec.secret
            field_schema["description"] = "Secret field (value will be masked in errors)"
        end

        properties[String(fname)] = field_schema

        # Determine if field is required
        # Required if: not optional AND no default value
        if !fspec.is_optional && !fspec.has_default
            push!(required, String(fname))
        end
    end

    # Build the root schema
    json_schema = Dict{String,Any}(
        "\$schema" => "http://json-schema.org/draft-07/schema#",
        "type" => "object",
        "properties" => properties
    )

    # Add required fields if any
    if !isempty(required)
        json_schema["required"] = sort(required)
    end

    # Add additionalProperties based on spec.extra
    if spec.extra == :forbid
        json_schema["additionalProperties"] = false
    elseif spec.extra == :allow
        json_schema["additionalProperties"] = true
    end
    # :ignore case: don't add the property (defaults to schema behavior)

    return json_schema
end

"""
    model_dump(instance::T; keys::Symbol=:symbol) where T -> Dict

Convert a struct instance to a Dict representation.

# Arguments
- `instance::T`: The struct instance to convert
- `keys::Symbol`: Key type for the resulting dictionary (`:symbol` or `:string`, default: `:symbol`)

# Returns
- `Dict{Symbol,Any}` if `keys=:symbol` (default)
- `Dict{String,Any}` if `keys=:string`

# Example
```julia
@model struct User
    name::String
    email::String
    age::Int = 0
end

user = model_validate(User, Dict(:name => "Alice", :email => "alice@example.com"))

# Symbol keys (default)
dict = model_dump(user)
# => Dict(:name => "Alice", :email => "alice@example.com", :age => 0)

# String keys (for JSON compatibility)
dict_str = model_dump(user; keys=:string)
# => Dict("name" => "Alice", "email" => "alice@example.com", "age" => 0)
```

See also: [`model_dump_json`](@ref), [`model_validate`](@ref), [`model_copy`](@ref)
"""
function model_dump(instance::T; keys::Symbol=:symbol) where T
    if keys == :symbol
        result = Dict{Symbol,Any}()
        for fname in fieldnames(T)
            result[fname] = getfield(instance, fname)
        end
        return result
    elseif keys == :string
        result = Dict{String,Any}()
        for fname in fieldnames(T)
            result[String(fname)] = getfield(instance, fname)
        end
        return result
    else
        throw(ArgumentError("keys must be :symbol or :string, got :$keys"))
    end
end

"""
    model_dump_json(instance::T) where T -> String

Convert a struct instance to a JSON string.

# Arguments
- `instance::T`: The struct instance to convert

# Returns
- `String`: JSON string representation of the instance

# Example
```julia
@model struct User
    name::String
    email::String
    age::Int = 0
end

user = model_validate(User, Dict(:name => "Alice", :email => "alice@example.com"))
json_str = model_dump_json(user)
# => "{\\"name\\":\\"Alice\\",\\"email\\":\\"alice@example.com\\",\\"age\\":0}"
```

See also: [`model_dump`](@ref), [`model_validate_json`](@ref)
"""
function model_dump_json(instance::T) where T
    dict = model_dump(instance; keys=:string)
    return JSON3.write(dict)
end
