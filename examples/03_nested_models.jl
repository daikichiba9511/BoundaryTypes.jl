# Nested Models Example
#
# This example demonstrates validation of nested struct hierarchies.
# BoundaryTypes.jl automatically validates nested models recursively.

using BoundaryTypes

# 1. Simple Nested Structure
println("=" ^ 80)
println("Simple Nested Validation")
println("=" ^ 80)

# Define nested models
@model struct Address
    street::String
    city::String
    zipcode::String
    country::String
end

@rules Address begin
    field(:street, minlen(5))
    field(:city, minlen(2))
    field(:zipcode, regex(r"^\d{5}(-\d{4})?$"))  # US ZIP code format
    field(:country, minlen(2))
end

@model struct Person
    name::String
    email::String
    address::Address  # Nested model
end

@rules Person begin
    field(:name, minlen(1))
    field(:email, email())
    # No need to explicitly validate :address
    # Nested validation happens automatically!
end

# Valid nested data
valid_person = Dict(
    :name => "Alice Smith",
    :email => "alice@example.com",
    :address => Dict(
        :street => "123 Main Street",
        :city => "Boston",
        :zipcode => "02101",
        :country => "USA"
    )
)

person = model_validate(Person, valid_person)
println("✓ Person created: $(person.name)")
println("  Lives in: $(person.address.city), $(person.address.country)")
println("  ZIP: $(person.address.zipcode)")
println()

# Invalid nested data - error in nested field
invalid_zipcode = Dict(
    :name => "Bob Johnson",
    :email => "bob@example.com",
    :address => Dict(
        :street => "456 Oak Ave",
        :city => "Seattle",
        :zipcode => "INVALID",  # Invalid ZIP format
        :country => "USA"
    )
)

ok, result = try_model_validate(Person, invalid_zipcode)
if !ok
    println("✗ Validation failed in nested field:")
    for err in result.errors
        # Error path shows nested structure: [:address, :zipcode]
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 2. Multiple Levels of Nesting
println("=" ^ 80)
println("Multi-Level Nested Validation")
println("=" ^ 80)

@model struct GeoCoordinates
    latitude::Float64
    longitude::Float64
end

@rules GeoCoordinates begin
    field(:latitude, between(-90.0, 90.0))
    field(:longitude, between(-180.0, 180.0))
end

@model Base.@kwdef struct Location
    address::Address  # Already defined above
    coordinates::Union{Nothing,GeoCoordinates} = nothing
end

@rules Location begin
    # address and coordinates validated automatically
end

@model struct Business
    name::String
    website::String
    location::Location  # Nested location with nested address
end

@rules Business begin
    field(:name, minlen(1))
    field(:website, url())
end

# Valid multi-level nested data
valid_business = Dict(
    :name => "Julia Coffee Shop",
    :website => "https://juliacoffee.example.com",
    :location => Dict(
        :address => Dict(
            :street => "789 Park Avenue",
            :city => "Portland",
            :zipcode => "97201",
            :country => "USA"
        ),
        :coordinates => Dict(
            :latitude => 45.5152,
            :longitude => -122.6784
        )
    )
)

business = model_validate(Business, valid_business)
println("✓ Business created: $(business.name)")
println("  Location: $(business.location.address.city)")
if !isnothing(business.location.coordinates)
    println("  Coordinates: $(business.location.coordinates.latitude), $(business.location.coordinates.longitude)")
end
println()

# Invalid coordinates
invalid_coords = Dict(
    :name => "Another Shop",
    :website => "https://anothershop.example.com",
    :location => Dict(
        :address => Dict(
            :street => "100 First St",
            :city => "Austin",
            :zipcode => "78701",
            :country => "USA"
        ),
        :coordinates => Dict(
            :latitude => 91.0,  # Invalid: > 90
            :longitude => -97.7431
        )
    )
)

ok, result = try_model_validate(Business, invalid_coords)
if !ok
    println("✗ Validation failed in deeply nested field:")
    for err in result.errors
        # Error path shows full nesting: [:location, :coordinates, :latitude]
        println("  - $(join(err.path, ".")): $(err.message)")
    end
end
println()

# 3. Optional Nested Models
println("=" ^ 80)
println("Optional Nested Models")
println("=" ^ 80)

@model Base.@kwdef struct Company
    name::String
    primary_contact::Person
    billing_address::Union{Nothing,Address} = nothing  # Optional nested model
end

@rules Company begin
    field(:name, minlen(1))
end

# Without optional nested model
company_without_billing = Dict(
    :name => "Tech Startup Inc",
    :primary_contact => Dict(
        :name => "John Doe",
        :email => "john@techstartup.example.com",
        :address => Dict(
            :street => "1 Innovation Way",
            :city => "San Francisco",
            :zipcode => "94103",
            :country => "USA"
        )
    )
)

company1 = model_validate(Company, company_without_billing)
println("✓ Company created: $(company1.name)")
println("  Primary contact: $(company1.primary_contact.name)")
println("  Billing address: $(isnothing(company1.billing_address) ? "Not provided" : "Provided")")
println()

# With optional nested model
company_with_billing = Dict(
    :name => "Enterprise Corp",
    :primary_contact => Dict(
        :name => "Jane Smith",
        :email => "jane@enterprise.example.com",
        :address => Dict(
            :street => "500 Corporate Blvd",
            :city => "New York",
            :zipcode => "10001",
            :country => "USA"
        )
    ),
    :billing_address => Dict(
        :street => "PO Box 1234",
        :city => "New York",
        :zipcode => "10002",
        :country => "USA"
    )
)

company2 = model_validate(Company, company_with_billing)
println("✓ Company created: $(company2.name)")
println("  Billing address: $(company2.billing_address.city)")
println()

println("=" ^ 80)
println("Tip: Nested validation is automatic - define models and rules separately!")
println("=" ^ 80)
