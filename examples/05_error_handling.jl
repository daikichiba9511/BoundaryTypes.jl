# Error Handling Example
#
# This example demonstrates different error handling patterns
# and how to work with ValidationError objects.

using BoundaryTypes

# Define a model for demonstration
@model struct UserRegistration
    username::String
    email::String
    password::String
    age::Int
    terms_accepted::Bool
end

@rules UserRegistration begin
    field(:username, minlen(3), maxlen(20), regex(r"^[a-zA-Z0-9_]+$"))
    field(:email, email())
    field(:password, minlen(12), secret())
    field(:age, ge(13), le(120))
    field(:terms_accepted, custom(
        x -> x == true;
        code = :terms_required,
        msg = "must accept terms of service"
    ))
end

# 1. Throwing vs Non-Throwing Validation
println("=" ^ 80)
println("1. Throwing vs Non-Throwing Validation")
println("=" ^ 80)

# Approach 1: model_validate (throws ValidationError)
println("Approach 1: Using model_validate (throws on error)")
try
    invalid_data = Dict(
        :username => "ab",  # Too short
        :email => "invalid-email",
        :password => "short",
        :age => 25,
        :terms_accepted => true
    )

    user = model_validate(UserRegistration, invalid_data)
    println("✓ User created")
catch e
    if e isa ValidationError
        println("✗ ValidationError caught:")
        println("  Total errors: $(length(e.errors))")
        for err in e.errors
            println("    - $(join(err.path, ".")): $(err.message)")
        end
    else
        rethrow(e)
    end
end
println()

# Approach 2: try_model_validate (returns status + result)
println("Approach 2: Using try_model_validate (returns ok, result)")
invalid_data = Dict(
    :username => "ab",
    :email => "invalid-email",
    :password => "short",
    :age => 25,
    :terms_accepted => true
)

ok, result = try_model_validate(UserRegistration, invalid_data)
if ok
    println("✓ User created: $(result.username)")
else
    println("✗ Validation failed:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 2. Comprehensive Error Collection
println("=" ^ 80)
println("2. Comprehensive Error Collection")
println("=" ^ 80)
println("BoundaryTypes collects ALL validation errors before failing")
println()

# Multiple errors across different fields
multi_error_data = Dict(
    :username => "a",              # Too short
    :email => "not-an-email",     # Invalid format
    :password => "short",         # Too short
    :age => 10,                   # Too young
    :terms_accepted => false      # Not accepted
)

ok, result = try_model_validate(UserRegistration, multi_error_data)
if !ok
    println("Found $(length(result.errors)) validation errors:")
    for (i, err) in enumerate(result.errors)
        println("  $(i). Field: $(join(err.path, "."))")
        println("     Code: $(err.code)")
        println("     Message: $(err.message)")
    end
end
println()

# 3. Working with FieldError Objects
println("=" ^ 80)
println("3. Working with FieldError Objects")
println("=" ^ 80)

ok, result = try_model_validate(UserRegistration, multi_error_data)
if !ok
    println("ValidationError properties:")
    println("  - errors: Vector{FieldError} with $(length(result.errors)) items")
    println()

    for err in result.errors
        println("FieldError for field: $(join(err.path, "."))")
        println("  - path: $(err.path)  (field path as Vector{Symbol})")
        println("  - code: $(err.code)  (error code as Symbol)")
        println("  - msg: $(err.message)   (human-readable message)")
        println("  - value: $(err.got)  (the invalid value)")
        println("  - secret: $(err.secret)  (is field marked as secret)")
        println()
    end
end

# 4. Filtering and Categorizing Errors
println("=" ^ 80)
println("4. Filtering and Categorizing Errors")
println("=" ^ 80)

ok, result = try_model_validate(UserRegistration, multi_error_data)
if !ok
    # Filter errors by code
    minlen_errors = filter(e -> e.code == :minlen, result.errors)
    regex_errors = filter(e -> e.code == :regex, result.errors)
    email_errors = filter(e -> e.code == :email, result.errors)

    println("Errors by type:")
    println("  - Length errors: $(length(minlen_errors))")
    println("  - Format errors: $(length(regex_errors))")
    println("  - Email errors: $(length(email_errors))")
    println()

    # Get errors for specific field
    username_errors = filter(e -> :username in e.path, result.errors)
    println("Errors for username field: $(length(username_errors))")
    for err in username_errors
        println("  - $(err.message)")
    end
end
println()

# 5. Custom Error Handling Logic
println("=" ^ 80)
println("5. Custom Error Handling Logic")
println("=" ^ 80)

function process_registration(data::Dict)
    ok, result = try_model_validate(UserRegistration, data)

    if ok
        # Success case
        println("✓ Registration successful!")
        println("  Username: $(result.username)")
        println("  Email: $(result.email)")
        return result
    else
        # Error case - custom handling
        println("✗ Registration failed")

        # Check for critical errors
        has_email_error = any(e -> :email in e.path, result.errors)
        has_password_error = any(e -> :password in e.path, result.errors)
        has_terms_error = any(e -> e.code == :terms_required, result.errors)

        if has_terms_error
            println("  ⚠ CRITICAL: Terms of service must be accepted")
        end

        if has_email_error
            println("  ⚠ Email address is invalid")
        end

        if has_password_error
            println("  ⚠ Password does not meet security requirements")
        end

        println()
        println("  All errors:")
        for err in result.errors
            println("    - $(join(err.path, ".")): $(err.message)")
        end

        return nothing
    end
end

# Test custom handler
test_data = Dict(
    :username => "validuser",
    :email => "invalid",
    :password => "short",
    :age => 25,
    :terms_accepted => false
)

process_registration(test_data)
println()

# 6. JSON Error Responses (for APIs)
println("=" ^ 80)
println("6. JSON Error Responses")
println("=" ^ 80)

function format_errors_for_api(validation_error::ValidationError)
    # Convert errors to JSON-friendly format
    error_dict = Dict(
        "status" => "validation_failed",
        "errors" => [
            Dict(
                "field" => join(err.path, "."),
                "code" => string(err.code),
                "message" => err.message
            )
            for err in validation_error.errors
        ]
    )
    return error_dict
end

ok, result = try_model_validate(UserRegistration, multi_error_data)
if !ok
    api_response = format_errors_for_api(result)
    println("API error response:")
    println("  Status: $(api_response["status"])")
    println("  Errors:")
    for (i, err) in enumerate(api_response["errors"])
        println("    $(i). $(err["field"]): $(err["message"]) [$(err["code"])]")
    end
end
println()

# 7. Graceful Degradation
println("=" ^ 80)
println("7. Graceful Degradation Pattern")
println("=" ^ 80)

function create_user_with_defaults(data::Dict)
    ok, result = try_model_validate(UserRegistration, data)

    if ok
        return (success = true, user = result, errors = nothing)
    else
        # For demo: show which fields are valid vs invalid
        valid_fields = Symbol[]
        invalid_fields = Symbol[]

        all_fields = [:username, :email, :password, :age, :terms_accepted]
        for field in all_fields
            has_error = any(e -> field in e.path, result.errors)
            if has_error
                push!(invalid_fields, field)
            else
                push!(valid_fields, field)
            end
        end

        return (
            success = false,
            user = nothing,
            errors = result,
            valid_fields = valid_fields,
            invalid_fields = invalid_fields
        )
    end
end

response = create_user_with_defaults(multi_error_data)
println("Graceful degradation result:")
println("  Success: $(response.success)")
if !response.success
    println("  Valid fields: $(join(response.valid_fields, ", "))")
    println("  Invalid fields: $(join(response.invalid_fields, ", "))")
end
println()

println("=" ^ 80)
println("Tip: Use try_model_validate for production error handling!")
println("=" ^ 80)
