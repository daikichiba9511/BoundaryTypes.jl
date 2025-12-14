"""
    @model struct TypeName ... end

Register a struct as a validated model and automatically infer field specifications
from the struct definition.

# Field Inference Rules

The macro analyzes each field declaration and infers its properties:

| Struct Definition                | Interpretation                    |
|:---------------------------------|:----------------------------------|
| `x::T`                           | Required field                    |
| `x::T = v`                       | Field with default value          |
| `x::Union{Nothing,T}`            | Optional field                    |
| `x::Union{Nothing,T} = nothing`  | Optional field with default       |

# Usage

```julia
@model struct User
    email::String                          # Required
    password::String                       # Required
    age::Int = 0                          # Default value
    nickname::Union{Nothing,String} = nothing  # Optional with default
end
```

After registration, use `model_validate(User, raw_input)` to validate and construct instances.

# Implementation Notes

- The original struct definition is preserved
- Field metadata is stored in `_MODEL_SPECS`
- Rules defined via `@rules` are merged automatically
- The struct can still be constructed normally, but validation is only applied through `model_validate`

See also: [`@rules`](@ref), [`model_validate`](@ref), [`FieldSpec`](@ref)
"""
macro model(def)
    struct_def = def
    if def isa Expr && def.head == :macrocall
        struct_def = def.args[end]
    end
    @assert struct_def isa Expr && struct_def.head in (:struct, :mutable)

    # robust type name symbol & body extraction
    has_bool = (struct_def.args[1] isa Bool)
    Tname_sym = has_bool ? (struct_def.args[2]::Symbol) : (struct_def.args[1]::Symbol)
    body = has_bool ? struct_def.args[3] : struct_def.args[2]
    stmts = (body isa Expr && body.head == :block) ? body.args : Any[]

    fs_pairs = Tuple{Symbol,Expr}[]

    for st in stmts
        st isa LineNumberNode && continue
        (st isa Expr && st.head == :doc) && continue

        if st isa Expr && st.head == :(=)
            lhs, rhs = st.args
            @assert lhs isa Expr && lhs.head == :(::)
            fname = lhs.args[1]::Symbol
            ftyp  = lhs.args[2]

            push!(fs_pairs, (fname,
                :(BoundaryTypes.FieldSpec($(QuoteNode(fname)), $ftyp, true, $rhs, BoundaryTypes._is_optional_type($ftyp), false, BoundaryTypes.Rule[]))
            ))

        elseif st isa Expr && st.head == :(::)
            fname = st.args[1]::Symbol
            ftyp  = st.args[2]

            push!(fs_pairs, (fname,
                :(BoundaryTypes.FieldSpec($(QuoteNode(fname)), $ftyp, false, nothing, BoundaryTypes._is_optional_type($ftyp), false, BoundaryTypes.Rule[]))
            ))
        end
    end

    quote
        $def
        begin
            local T = getfield(@__MODULE__, $(QuoteNode(Tname_sym)))

            local _fields = Dict{Symbol,BoundaryTypes.FieldSpec}()
            $(Expr(:block, [:( _fields[$(QuoteNode(k))] = $v ) for (k, v) in fs_pairs ]...))

            # merge rules if already registered (keyed by DataType)
            local rs = get(BoundaryTypes._RULES, T, Dict{Symbol, Vector{Any}}())
            for (k, v) in rs
                if haskey(_fields, k)
                    local base = _fields[k]
                    local rules = BoundaryTypes.Rule[]
                    local secret_flag = false

                    for item in v
                        if item isa BoundaryTypes.SecretTag
                            secret_flag = true
                        elseif item isa BoundaryTypes.Rule
                            push!(rules, item)
                        end
                    end

                    _fields[k] = BoundaryTypes.FieldSpec(
                        base.name,
                        base.typ,
                        base.has_default,
                        base.default_expr,
                        base.is_optional,
                        secret_flag,
                        rules
                    )
                end
            end

            BoundaryTypes._MODEL_SPECS[T] = BoundaryTypes.ModelSpec(_fields, :forbid)
        end
    end |> esc
end


"""
    field(name::Symbol, rules...)

Define validation rules for a field within an `@rules` block.

!!! warning "Macro-only syntax"
    This is a DSL syntax element that **only works inside `@rules` macro blocks**.
    It is not a regular function and will error if called directly.

# Arguments
- `name::Symbol`: Field name as a symbol (e.g., `:email`, `:password`)
- `rules...`: One or more validation rules and/or attributes to apply

# Available Rules
- **String validation**: `minlen(n)`, `regex(pattern)`
- **Numeric validation**: `ge(n)`, `le(n)`
- **Presence validation**: `present()`, `notnothing()`
- **Attributes**: `secret()` (masks value in errors)
- **Custom**: `custom(fn; code=:code, msg="message")`

# Example
```julia
@model struct User
    email::String
    password::String
    age::Int = 0
    bio::Union{Nothing,String} = nothing
end

@rules User begin
    # Multiple rules can be chained
    field(:email, regex(r"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\$"))

    # Combine validation + secret attribute
    field(:password, minlen(12), regex(r"[A-Z]"), secret())

    # Numeric constraints
    field(:age, ge(0), le(150))

    # Optional fields - rules only apply when value is present
    field(:bio, minlen(10))
end
```

# How It Works
- Rules are applied in order during validation
- All rules are checked (no fail-fast) to collect all errors
- For optional fields (`Union{Nothing,T}`), rules are skipped if value is `nothing`
- Use `present()` or `notnothing()` to enforce presence on optional fields

# See Also
- [`@rules`](@ref): The macro that processes `field()` declarations
- [`@model`](@ref): Define a validatable model
- Rule builders: [`minlen`](@ref), [`regex`](@ref), [`ge`](@ref), [`le`](@ref),
  [`present`](@ref), [`notnothing`](@ref), [`secret`](@ref), [`custom`](@ref)
"""
function field(::Symbol, rules...)
    error("field() can only be used inside @rules macro block")
end


"""
    @rules TypeName begin ... end

Define validation rules for a model type registered with `@model`.

# Syntax

```julia
@rules TypeName begin
    field(:field_name, rule1, rule2, ...)
    field(:other_field, rule3, rule4, ...)
end
```

Each `field(:name, ...)` statement declares validation rules for the specified field.
Multiple rules are applied in order, and all errors are collected.

# Validation Semantics

## Required Fields (`x::T`)
- Missing from input → error
- Present in input → validate with all rules

## Fields with Defaults (`x::T = v`)
- Missing from input → use default value
- **Default value is also validated** against all rules
- Present in input → validate with all rules

## Optional Fields (`x::Union{Nothing,T}`)
- Missing from input → OK (`nothing`)
- Value is `nothing` → most rules are skipped (except `present()`, `notnothing()`)
- Value is present and not `nothing` → validate with all rules

# Available Rules

- `minlen(n)`: Minimum string length
- `regex(re)`: Pattern matching
- `ge(n)`, `le(n)`: Numeric constraints
- `present()`: Require field presence in input
- `notnothing()`: Prohibit `nothing` values
- `secret()`: Mask value in error messages (not a validation rule)
- `custom(f; code, msg)`: Custom validation logic

# Example

```julia
@model struct Signup
    email::String
    password::String
    age::Int = 0
    nickname::Union{Nothing,String} = nothing
end

@rules Signup begin
    field(:email, regex(r"^[^@\\s]+@[^@\\s]+\\.[^@\\s]+\$"))
    field(:password, minlen(12), regex(r"[A-Z]"), regex(r"[0-9]"), secret())
    field(:age, ge(0), le(150))
    field(:nickname, minlen(3))  # Only validated if provided and not nothing
end
```

# Order of Execution

Rules can be defined before or after the `@model` macro. They are automatically merged
when the model is registered or when `@rules` is invoked, whichever comes later.

See also: [`@model`](@ref), [`model_validate`](@ref), [`minlen`](@ref), [`regex`](@ref)
"""
macro rules(Texpr, block)
    # Require @rules TypeName begin ... end
    @assert Texpr isa Symbol "Usage: @rules TypeName begin ... end"
    Tsym = Texpr

    stmts = block isa Expr && block.head == :block ? block.args : Any[block]

    reg = Expr[]
    for st in stmts
        st isa LineNumberNode && continue

        @assert st isa Expr && st.head == :call && st.args[1] == :field "Only field(:name, ...) statements are supported"

        fname_expr = st.args[2]
        @assert fname_expr isa QuoteNode && fname_expr.value isa Symbol "field name must be a literal Symbol, e.g. field(:email, ...)"

        fname = fname_expr.value::Symbol

        rule_exprs = st.args[3:end]  # keep as-is (do not esc here)
        # qualify rule calls like regex(...), minlen(...), secret() to BoundaryTypes.regex(...)
        qualify_rule(ex) = begin
            if ex isa Expr && ex.head == :call && ex.args[1] isa Symbol
                # BoundaryTypes.<symbol>(...)
                Expr(:call, Expr(:., :BoundaryTypes, QuoteNode(ex.args[1])), ex.args[2:end]...)
            else
                ex
            end
        end

        push!(reg, quote
            local T = getfield(@__MODULE__, $(QuoteNode(Tsym)))  # DataType
            local d = get!(BoundaryTypes._RULES, T, Dict{Symbol, Vector{Any}}())
            local arr = get!(d, $(QuoteNode(fname)), Any[])
            local _rules = Any[$(map(qualify_rule, rule_exprs)...)]
            append!(arr, _rules)
        end)
    end

    # Optional: if model already registered, re-merge rules immediately
    merge_expr = quote
        local T = getfield(@__MODULE__, $(QuoteNode(Tsym)))
        local spec = get(BoundaryTypes._MODEL_SPECS, T, nothing)
        if spec !== nothing
            local rs = get(BoundaryTypes._RULES, T, Dict{Symbol, Vector{Any}}())
            local _fields = copy(spec.fields)
            for (k, v) in rs
                if haskey(_fields, k)
                    local base = _fields[k]
                    local rules = BoundaryTypes.Rule[]
                    local secret_flag = base.secret
                    for item in v
                        if item isa BoundaryTypes.SecretTag
                            secret_flag = true
                        elseif item isa BoundaryTypes.Rule
                            push!(rules, item)
                        end
                    end
                    _fields[k] = BoundaryTypes.FieldSpec(base.name, base.typ, base.has_default, base.default_expr,
                                                        base.is_optional, secret_flag, rules)
                end
            end
            BoundaryTypes._MODEL_SPECS[T] = BoundaryTypes.ModelSpec(_fields, spec.extra)
        end
    end

    return esc(quote
        $(reg...)
        $merge_expr
    end)
end


"""
    @validated_model struct TypeName ... end

Register a struct as a validated model and automatically generate a keyword constructor
that performs validation via `model_validate`.

This macro combines `@model` functionality with automatic constructor generation,
providing a Pydantic-like experience where constructors always validate.

# Difference from @model

- `@model`: Registers the model but requires explicit `model_validate(T, data)` calls
- `@validated_model`: Registers the model AND generates `T(; kwargs...) = model_validate(T, kwargs)`

# Field Inference Rules

Same as `@model`:

| Struct Definition                | Interpretation                    |
|:---------------------------------|:----------------------------------|
| `x::T`                           | Required field                    |
| `x::T = v`                       | Field with default value          |
| `x::Union{Nothing,T}`            | Optional field                    |
| `x::Union{Nothing,T} = nothing`  | Optional field with default       |

# Generated Constructor

The macro automatically generates:
```julia
TypeName(; kwargs...) = BoundaryTypes.model_validate(TypeName, kwargs)
```

This ensures all instances created via the keyword constructor are validated.

# Usage

```julia
@validated_model struct User
    email::String
    password::String
    age::Int = 0
end

@rules User begin
    field(:email, regex(r"@"))
    field(:password, minlen(8), secret())
    field(:age, ge(0), le(150))
end

# Direct construction with validation
user = User(email="user@example.com", password="secure123")
# Equivalent to: model_validate(User, (; email="user@example.com", password="secure123"))

# Invalid construction throws ValidationError
try
    User(email="invalid", password="short")  # ValidationError
catch e::ValidationError
    println(e)
end
```

# Important Notes

- The generated constructor only works with keyword arguments
- Positional constructors still work but bypass validation
- To enforce validation always, make fields `const` or add inner constructor guards
- Use `@model` if you want to keep explicit `model_validate` calls

See also: [`@model`](@ref), [`@rules`](@ref), [`model_validate`](@ref)
"""
macro validated_model(def)
    struct_def = def
    if def isa Expr && def.head == :macrocall
        struct_def = def.args[end]
    end
    @assert struct_def isa Expr && struct_def.head in (:struct, :mutable)

    # robust type name symbol & body extraction
    has_bool = (struct_def.args[1] isa Bool)
    Tname_sym = has_bool ? (struct_def.args[2]::Symbol) : (struct_def.args[1]::Symbol)
    body = has_bool ? struct_def.args[3] : struct_def.args[2]
    stmts = (body isa Expr && body.head == :block) ? body.args : Any[]

    fs_pairs = Tuple{Symbol,Expr}[]
    new_stmts = Any[]  # Struct body without default values

    for st in stmts
        st isa LineNumberNode && (push!(new_stmts, st); continue)
        (st isa Expr && st.head == :doc) && (push!(new_stmts, st); continue)

        if st isa Expr && st.head == :(=)
            lhs, rhs = st.args
            @assert lhs isa Expr && lhs.head == :(::)
            fname = lhs.args[1]::Symbol
            ftyp  = lhs.args[2]

            # Store field spec with default value
            # Note: _is_optional_type must be called at runtime, not at macro expansion time
            push!(fs_pairs, (fname,
                :(BoundaryTypes.FieldSpec($(QuoteNode(fname)), $ftyp, true, $rhs, BoundaryTypes._is_optional_type($ftyp), false, BoundaryTypes.Rule[]))
            ))

            # Add field without default to struct definition
            push!(new_stmts, lhs)

        elseif st isa Expr && st.head == :(::)
            fname = st.args[1]::Symbol
            ftyp  = st.args[2]

            push!(fs_pairs, (fname,
                :(BoundaryTypes.FieldSpec($(QuoteNode(fname)), $ftyp, false, nothing, BoundaryTypes._is_optional_type($ftyp), false, BoundaryTypes.Rule[]))
            ))

            # Add field to struct definition
            push!(new_stmts, st)
        else
            # Keep other statements (e.g., inner constructors)
            push!(new_stmts, st)
        end
    end

    # Create new struct definition without default values
    new_body = Expr(:block, new_stmts...)
    if has_bool
        new_def = Expr(:struct, struct_def.args[1], struct_def.args[2], new_body)
    else
        new_def = Expr(:struct, struct_def.args[1], new_body)
    end

    quote
        $new_def
        begin
            local T = getfield(@__MODULE__, $(QuoteNode(Tname_sym)))

            local _fields = Dict{Symbol,BoundaryTypes.FieldSpec}()
            $(Expr(:block, [:( _fields[$(QuoteNode(k))] = $v ) for (k, v) in fs_pairs ]...))

            # merge rules if already registered (keyed by DataType)
            local rs = get(BoundaryTypes._RULES, T, Dict{Symbol, Vector{Any}}())
            for (k, v) in rs
                if haskey(_fields, k)
                    local base = _fields[k]
                    local rules = BoundaryTypes.Rule[]
                    local secret_flag = false

                    for item in v
                        if item isa BoundaryTypes.SecretTag
                            secret_flag = true
                        elseif item isa BoundaryTypes.Rule
                            push!(rules, item)
                        end
                    end

                    _fields[k] = BoundaryTypes.FieldSpec(
                        base.name,
                        base.typ,
                        base.has_default,
                        base.default_expr,
                        base.is_optional,
                        secret_flag,
                        rules
                    )
                end
            end

            BoundaryTypes._MODEL_SPECS[T] = BoundaryTypes.ModelSpec(_fields, :forbid)
        end

        # Generate keyword constructor that validates
        function $(Tname_sym)(; kwargs...)
            BoundaryTypes.model_validate($(Tname_sym), kwargs)
        end
    end |> esc
end
