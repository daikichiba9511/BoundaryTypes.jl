# Advanced Validation Rules Example
#
# This example demonstrates advanced validation rules including
# string patterns, numeric constraints, and custom validators.

using BoundaryTypes

# 1. Advanced String Validation
println("=" ^ 80)
println("Advanced String Validation")
println("=" ^ 80)

@model struct WebsiteProfile
    username::String
    email::String
    website::String
    profile_id::String  # UUID
    status::String
end

@rules WebsiteProfile begin
    # Username: alphanumeric, 3-20 characters
    field(:username, minlen(3), maxlen(20), regex(r"^[a-zA-Z0-9_]+$"))

    # Email: built-in email validator
    field(:email, email())

    # Website: built-in URL validator
    field(:website, url())

    # Profile ID: built-in UUID validator
    field(:profile_id, uuid())

    # Status: must be one of predefined values
    field(:status, choices(["active", "inactive", "suspended"]))
end

# Valid profile
valid_profile = Dict(
    :username => "alice_dev",
    :email => "alice@example.com",
    :website => "https://alice.dev",
    :profile_id => "550e8400-e29b-41d4-a716-446655440000",
    :status => "active"
)

profile = model_validate(WebsiteProfile, valid_profile)
println("✓ Profile created: @$(profile.username)")
println("  Website: $(profile.website)")
println("  Status: $(profile.status)")
println()

# Invalid choices
invalid_status = Dict(
    :username => "bob_dev",
    :email => "bob@example.com",
    :website => "https://bob.dev",
    :profile_id => "550e8400-e29b-41d4-a716-446655440001",
    :status => "pending"  # Not in choices
)

ok, result = try_model_validate(WebsiteProfile, invalid_status)
if !ok
    println("✗ Invalid status:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 2. Advanced Numeric Validation
println("=" ^ 80)
println("Advanced Numeric Validation")
println("=" ^ 80)

@model struct Product
    name::String
    price::Float64
    quantity::Int
    discount_percent::Float64
    rating::Float64
end

@rules Product begin
    field(:name, minlen(1))

    # Price: must be strictly positive
    field(:price, gt(0.0))

    # Quantity: non-negative, must be multiple of 10
    field(:quantity, ge(0), multiple_of(10))

    # Discount: between 0% and 100%
    field(:discount_percent, between(0.0, 100.0))

    # Rating: strictly between 0 and 5
    field(:rating, gt(0.0), lt(5.0))
end

# Valid product
valid_product = Dict(
    :name => "Julia Programming Book",
    :price => 49.99,
    :quantity => 100,
    :discount_percent => 15.0,
    :rating => 4.5
)

product = model_validate(Product, valid_product)
println("✓ Product created: $(product.name)")
println("  Price: \$$(product.price) ($(product.discount_percent)% off)")
println("  In stock: $(product.quantity) units")
println("  Rating: $(product.rating)/5")
println()

# Invalid quantity (not multiple of 10)
invalid_quantity = Dict(
    :name => "Another Product",
    :price => 29.99,
    :quantity => 15,  # Not multiple of 10
    :discount_percent => 10.0,
    :rating => 4.0
)

ok, result = try_model_validate(Product, invalid_quantity)
if !ok
    println("✗ Invalid quantity:")
    for err in result.errors
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 3. Custom Validation Rules
println("=" ^ 80)
println("Custom Validation Rules")
println("=" ^ 80)

@model struct Password
    value::String
end

@rules Password begin
    # Minimum length
    field(:value, minlen(12))

    # Must contain uppercase letter
    field(:value, regex(r"[A-Z]"))

    # Must contain lowercase letter
    field(:value, regex(r"[a-z]"))

    # Must contain digit
    field(:value, regex(r"[0-9]"))

    # Must contain special character
    field(:value, regex(r"[!@#$%^&*(),.?\":{}|<>]"))

    # Custom rule: cannot contain common weak patterns
    field(:value, custom(
        pwd -> !occursin("password", lowercase(pwd)) && !occursin("12345", pwd);
        code = :weak_password,
        msg = "password contains common weak patterns"
    ))
end

# Strong password
strong_pwd = Dict(:value => "MySecure@Pass2024!")
pwd = model_validate(Password, strong_pwd)
println("✓ Strong password accepted")
println()

# Weak password
weak_pwd = Dict(:value => "password123!")
ok, result = try_model_validate(Password, weak_pwd)
if !ok
    println("✗ Weak password rejected:")
    for err in result.errors
        println("  - $(err.message)")
    end
end
println()

# 4. Secret Fields
println("=" ^ 80)
println("Secret Field Masking")
println("=" ^ 80)

@model struct Credentials
    username::String
    password::String
    api_key::String
end

@rules Credentials begin
    field(:username, minlen(3))
    field(:password, minlen(12), secret())
    field(:api_key, minlen(32), secret())
end

# Invalid credentials with secret masking
invalid_creds = Dict(
    :username => "alice",
    :password => "short",  # Too short, but will be masked
    :api_key => "abc123"   # Too short, but will be masked
)

ok, result = try_model_validate(Credentials, invalid_creds)
if !ok
    println("✗ Validation errors with secret masking:")
    for err in result.errors
        # Secret fields show "***" instead of actual value
        println("  - $(join(err.path, ".")): $(err.message) (value: $(err.got))")
    end
end
println()

println("=" ^ 80)
println("Tip: Hover over rule functions in VSCode to see documentation!")
println("=" ^ 80)
