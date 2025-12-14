# Basic Usage Example
#
# This example demonstrates the fundamental usage of BoundaryTypes.jl
# for validating input data.

using BoundaryTypes

# 1. Define a model using @model macro
#    This creates a struct that can be validated
@model Base.@kwdef struct User
    name::String
    email::String
    age::Int
    bio::Union{Nothing,String} = nothing  # Optional field
end

# 2. Define validation rules using @rules macro
#    Rules are applied when validating input data
@rules User begin
    field(:name, minlen(1), maxlen(100))
    field(:email, email())
    field(:age, ge(0), le(150))
    field(:bio, minlen(10))  # Only validated if provided
end

# 3. Validate input data
println("=" ^ 80)
println("Valid Input Example")
println("=" ^ 80)

# Valid input - all fields pass validation
valid_data = Dict(
    :name => "Alice Smith",
    :email => "alice@example.com",
    :age => 30
)

user = model_validate(User, valid_data)
println("✓ Created user: $(user.name), $(user.email), age $(user.age)")
println()

# 4. Optional fields
println("=" ^ 80)
println("Optional Field Example")
println("=" ^ 80)

# With optional bio field
data_with_bio = Dict(
    :name => "Bob Johnson",
    :email => "bob@example.com",
    :age => 25,
    :bio => "Software engineer interested in Julia programming"
)

user_with_bio = model_validate(User, data_with_bio)
println("✓ Created user with bio: $(user_with_bio.name)")
println("  Bio: $(user_with_bio.bio)")
println()

# 5. Safe validation with try_model_validate
println("=" ^ 80)
println("Safe Validation Example")
println("=" ^ 80)

# Invalid input - email format is wrong
invalid_data = Dict(
    :name => "Charlie",
    :email => "not-an-email",  # Invalid email
    :age => 35
)

ok, result = try_model_validate(User, invalid_data)
if ok
    println("✓ Validation succeeded: $(result)")
else
    println("✗ Validation failed:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 6. Multiple validation errors
println("=" ^ 80)
println("Multiple Errors Example")
println("=" ^ 80)

# Multiple validation errors - all collected at once
multi_error_data = Dict(
    :name => "",  # Too short
    :email => "invalid",  # Invalid format
    :age => -5  # Negative age
)

ok, result = try_model_validate(User, multi_error_data)
if !ok
    println("✗ Found $(length(result.errors)) validation errors:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 7. Discovering available rules
println("=" ^ 80)
println("Discovering Available Rules")
println("=" ^ 80)
println("You can discover available validation rules using helper functions:")
println()
println("  available_rules()  # Show all rules")
println("  string_rules()     # Show string rules")
println("  numeric_rules()    # Show numeric rules")
println("  show_rule_examples()  # Show usage examples")
println()
println("Try running: string_rules()")
println()
