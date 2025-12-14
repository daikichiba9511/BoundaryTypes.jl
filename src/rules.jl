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
    gt(n; msg=nothing)

Require that a numeric value is strictly greater than `n`.

# Arguments
- `n`: Minimum value (exclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Product
    price::Float64
    discount_percent::Float64
end

@rules Product begin
    field(:price, gt(0.0))              # Price must be positive (> 0)
    field(:discount_percent, gt(0.0))   # Discount must be greater than 0
end
```

See also: [`ge`](@ref), [`lt`](@ref), [`between`](@ref)
"""
gt(n; msg=nothing) = Rule(:gt, (v, ctx)->(v isa Number && v > n), msg)

"""
    lt(n; msg=nothing)

Require that a numeric value is strictly less than `n`.

# Arguments
- `n`: Maximum value (exclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Measurement
    temperature::Float64
    humidity::Float64
end

@rules Measurement begin
    field(:temperature, lt(100.0))  # Must be below 100
    field(:humidity, lt(100.0))     # Humidity percentage below 100
end
```

See also: [`le`](@ref), [`gt`](@ref), [`between`](@ref)
"""
lt(n; msg=nothing) = Rule(:lt, (v, ctx)->(v isa Number && v < n), msg)

"""
    between(min, max; msg=nothing)

Require that a numeric value is within the range [min, max] (inclusive).

# Arguments
- `min`: Minimum value (inclusive)
- `max`: Maximum value (inclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Rating
    score::Int
    confidence::Float64
end

@rules Rating begin
    field(:score, between(1, 5))           # Score from 1 to 5
    field(:confidence, between(0.0, 1.0))  # Confidence from 0.0 to 1.0
end
```

See also: [`ge`](@ref), [`le`](@ref), [`gt`](@ref), [`lt`](@ref)
"""
function between(min, max; msg=nothing)
    return Rule(:between, (v, ctx) -> (v isa Number && min <= v <= max), msg)
end

"""
    multiple_of(n; msg=nothing)

Require that a numeric value is a multiple of `n`.

# Arguments
- `n`: The divisor (must be > 0)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Inventory
    quantity::Int
    batch_size::Int
end

@rules Inventory begin
    field(:quantity, multiple_of(10))   # Must be in multiples of 10
    field(:batch_size, multiple_of(5))  # Must be in multiples of 5
end

# Valid
inventory = model_validate(Inventory, Dict(:quantity => 100, :batch_size => 25))

# Invalid
model_validate(Inventory, Dict(:quantity => 103, :batch_size => 25))
# => ValidationError: quantity [multiple_of]: must be a multiple of the specified value
```

See also: [`custom`](@ref)
"""
function multiple_of(n; msg=nothing)
    n > 0 || throw(ArgumentError("multiple_of divisor must be positive"))
    return Rule(:multiple_of, (v, ctx) -> (v isa Number && v % n == 0), msg)
end

"""
    minlen(n; msg=nothing)

Require that a string or collection has at least `n` elements/characters.

For strings, checks character count. For collections (Vector, Set, etc.), checks element count.

# Arguments
- `n::Integer`: Minimum length (inclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Account
    username::String
    password::String
    tags::Vector{String}
end

@rules Account begin
    field(:username, minlen(3))   # At least 3 characters
    field(:password, minlen(12))  # At least 12 characters
    field(:tags, minlen(1))       # At least 1 tag required
end
```

See also: [`regex`](@ref), [`maxlen`](@ref)
"""
function minlen(n; msg=nothing)
    return Rule(:minlen, (v, ctx) -> begin
        if v isa AbstractString
            return length(v) >= n
        elseif v isa Union{AbstractArray, AbstractSet}
            return length(v) >= n
        else
            return false
        end
    end, msg)
end

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
    EachTag

Internal wrapper type for the `each(rule)` validation rule.

Stores a rule that should be applied to each element of a collection.

See also: [`each`](@ref)
"""
struct EachTag
    rule::Rule
end

"""
    each(rule; msg=nothing)

Apply a validation rule to each element of a collection (Array, Vector, Set, etc.).

This rule validates that every element in the collection satisfies the given rule.
If any element fails validation, an error is recorded with the element's index in the path.

# Arguments
- `rule::Rule`: The validation rule to apply to each element
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct TaggedPost
    tags::Vector{String}
    scores::Vector{Int}
end

@rules TaggedPost begin
    field(:tags, each(minlen(3)))     # Each tag must be at least 3 characters
    field(:scores, each(ge(0)))       # Each score must be non-negative
end

# Valid
post = model_validate(TaggedPost, Dict(
    :tags => ["julia", "programming", "web"],
    :scores => [10, 20, 30]
))

# Invalid - "ab" is too short
model_validate(TaggedPost, Dict(
    :tags => ["julia", "ab", "web"],
    :scores => [10, 20, 30]
))
# => ValidationError: tags[1] [minlen]: string too short
```

See also: [`minlen`](@ref), [`maxlen`](@ref)
"""
function each(rule; msg=nothing)
    # Return an EachTag wrapper instead of a Rule
    # This allows special handling in apply_rules!
    return EachTag(rule)
end

"""
    maxlen(n; msg=nothing)

Require that a string or collection has at most `n` elements/characters.

For strings, checks character count. For collections (Vector, Set, etc.), checks element count.

# Arguments
- `n::Integer`: Maximum length (inclusive)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Comment
    text::String
    tags::Vector{String}
end

@rules Comment begin
    field(:text, maxlen(280))    # Twitter-style character limit
    field(:tags, maxlen(5))      # At most 5 tags
end
```

See also: [`minlen`](@ref)
"""
function maxlen(n; msg=nothing)
    return Rule(:maxlen, (v, ctx) -> begin
        if v isa AbstractString
            return length(v) <= n
        elseif v isa Union{AbstractArray, AbstractSet}
            return length(v) <= n
        else
            return false
        end
    end, msg)
end

"""
    email(; msg=nothing)

Validate that a string is a valid email address format.

Uses a reasonable regex pattern for common email validation.
For production use, consider using a dedicated email validation library.

# Arguments
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct User
    email::String
end

@rules User begin
    field(:email, email())
end

# Valid
user = model_validate(User, Dict(:email => "user@example.com"))

# Invalid
model_validate(User, Dict(:email => "invalid-email"))
# => ValidationError: email [email]: invalid email format
```

See also: [`regex`](@ref), [`url`](@ref)
"""
function email(; msg=nothing)
    # Simple but reasonable email regex
    # Based on HTML5 email validation pattern
    email_pattern = r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    return Rule(:email, (v, ctx) -> (v isa AbstractString && occursin(email_pattern, v)), msg)
end

"""
    url(; msg=nothing)

Validate that a string is a valid URL format.

Supports http, https, ftp, and ftps protocols.

# Arguments
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Bookmark
    url::String
end

@rules Bookmark begin
    field(:url, url())
end

# Valid
bookmark = model_validate(Bookmark, Dict(:url => "https://example.com"))

# Invalid
model_validate(Bookmark, Dict(:url => "not-a-url"))
# => ValidationError: url [url]: invalid URL format
```

See also: [`regex`](@ref), [`email`](@ref)
"""
function url(; msg=nothing)
    # URL regex pattern supporting http(s) and ftp(s)
    url_pattern = r"^(https?|ftps?)://[^\s/$.?#].[^\s]*$"i
    return Rule(:url, (v, ctx) -> (v isa AbstractString && occursin(url_pattern, v)), msg)
end

"""
    uuid(; msg=nothing)

Validate that a string is a valid UUID (Universally Unique Identifier) format.

Supports both hyphenated and non-hyphenated UUID formats.

# Arguments
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Resource
    id::String
end

@rules Resource begin
    field(:id, uuid())
end

# Valid
resource = model_validate(Resource, Dict(:id => "550e8400-e29b-41d4-a716-446655440000"))

# Invalid
model_validate(Resource, Dict(:id => "not-a-uuid"))
# => ValidationError: id [uuid]: invalid UUID format
```

See also: [`regex`](@ref)
"""
function uuid(; msg=nothing)
    # UUID regex pattern (both hyphenated and non-hyphenated)
    uuid_pattern = r"^[0-9a-f]{8}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{4}-?[0-9a-f]{12}$"i
    return Rule(:uuid, (v, ctx) -> (v isa AbstractString && occursin(uuid_pattern, v)), msg)
end

"""
    choices(values; msg=nothing)

Validate that a value is one of the allowed choices (enum-like validation).

# Arguments
- `values`: Collection of allowed values (Vector, Set, Tuple, etc.)
- `msg::Union{Nothing,String}`: Custom error message (optional)

# Example
```julia
@model struct Task
    status::String
    priority::String
end

@rules Task begin
    field(:status, choices(["pending", "active", "completed", "archived"]))
    field(:priority, choices(["low", "medium", "high"]))
end

# Valid
task = model_validate(Task, Dict(:status => "active", :priority => "high"))

# Invalid
model_validate(Task, Dict(:status => "invalid", :priority => "high"))
# => ValidationError: status [choices]: must be one of the allowed values
```

See also: [`custom`](@ref)
"""
function choices(values; msg=nothing)
    allowed_set = Set(values)
    return Rule(:choices, (v, ctx) -> (v in allowed_set), msg)
end

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
    r.code === :minlen     && return "too short"
    r.code === :maxlen     && return "too long"
    r.code === :regex      && return "does not match required pattern"
    r.code === :ge         && return "must satisfy >= constraint"
    r.code === :le         && return "must satisfy <= constraint"
    r.code === :gt         && return "must satisfy > constraint"
    r.code === :lt         && return "must satisfy < constraint"
    r.code === :between    && return "must be within range"
    r.code === :multiple_of && return "must be a multiple of the specified value"
    r.code === :email      && return "invalid email format"
    r.code === :url        && return "invalid URL format"
    r.code === :uuid       && return "invalid UUID format"
    r.code === :choices    && return "must be one of the allowed values"
    r.code === :present    && return "field must be present"
    r.code === :notnothing && return "must not be nothing"
    return "validation failed"
end
