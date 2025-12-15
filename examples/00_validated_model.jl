# Validated Model Example
#
# This example demonstrates @validated_model, which combines model definition
# with automatic validation on construction.

using BoundaryTypes

println("=" ^ 80)
println("@validated_model vs @model")
println("=" ^ 80)
println()

# 1. Using @validated_model - validation happens automatically on construction
@validated_model struct User
    name::String
    email::String
    age::Int
    bio::Union{Nothing,String} = nothing  # Optional field with default
end

@rules User begin
    field(:name, minlen(1), maxlen(100))
    field(:email, email())
    field(:age, ge(0), le(150))
    field(:bio, minlen(10))  # Only validated if provided
end

println("With @validated_model, you can construct directly:")
println()

# Direct construction with validation - IDE autocomplete works!
user = User(
    name="Alice Smith",
    email="alice@example.com",
    age=30
)

println("✓ Created user: $(user.name), $(user.email), age $(user.age)")
println("  Type inference works: user.name, user.email, user.age are all autocompleted!")
println()

# 2. Optional fields work naturally
println("=" ^ 80)
println("Optional Fields")
println("=" ^ 80)
println()

user_with_bio = User(
    name="Bob Johnson",
    email="bob@example.com",
    age=25,
    bio="Software engineer interested in Julia programming"
)

println("✓ User with bio: $(user_with_bio.name)")
println("  Bio: $(user_with_bio.bio)")
println()

# 3. Validation errors are thrown on construction
println("=" ^ 80)
println("Validation Errors")
println("=" ^ 80)
println()

println("Attempting to create user with invalid data...")
try
    invalid_user = User(
        name="",  # Too short
        email="not-an-email",  # Invalid format
        age=-5  # Negative
    )
catch e
    if e isa ValidationError
        println("✗ ValidationError caught:")
        for err in e.errors
            println("  - $(join(err.path, ".")): $(err.message)")
        end
    else
        rethrow(e)
    end
end
println()

# 4. Comparison with @model
println("=" ^ 80)
println("@model requires explicit model_validate()")
println("=" ^ 80)
println()

@model Base.@kwdef struct Product
    name::String
    price::Float64
    quantity::Int = 0
end

@rules Product begin
    field(:name, minlen(1))
    field(:price, ge(0.0))
    field(:quantity, ge(0))
end

println("With @model, you must use model_validate():")
println()

# Must use model_validate explicitly
product = model_validate(Product, Dict(
    :name => "Widget",
    :price => 19.99,
    :quantity => 100
))

println("✓ Created product: $(product.name), \$$(product.price)")
println()

# 5. Use case recommendation
println("=" ^ 80)
println("When to Use Each")
println("=" ^ 80)
println()
println("Use @validated_model when:")
println("  • You want Pydantic-like automatic validation on construction")
println("  • You want better IDE autocomplete/type inference")
println("  • You're building APIs or user-facing constructors")
println()
println("Use @model when:")
println("  • You want explicit validation calls")
println("  • You need to separate struct definition from validation")
println("  • You want more control over when validation happens")
println()
