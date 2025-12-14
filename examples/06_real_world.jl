# Real-World Use Cases
#
# This example demonstrates practical, real-world scenarios where
# BoundaryTypes.jl provides value in production applications.

using BoundaryTypes
using JSON3

# ============================================================================
# Use Case 1: Web API Request Validation
# ============================================================================

println("=" ^ 80)
println("Use Case 1: Web API Request Validation")
println("=" ^ 80)
println()

@model Base.@kwdef struct CreateUserRequest
    username::String
    email::String
    password::String
    full_name::String
    age::Union{Nothing,Int} = nothing
    newsletter_opt_in::Bool = false
end

@rules CreateUserRequest begin
    field(:username, minlen(3), maxlen(20), regex(r"^[a-zA-Z0-9_]+$"))
    field(:email, email())
    field(:password, minlen(12), regex(r"[A-Z]"), regex(r"[a-z]"), regex(r"[0-9]"), secret())
    field(:full_name, minlen(1), maxlen(100))
    field(:age, ge(13), le(150))
end

# Simulate API request handler
function handle_user_registration(request_body::String)
    # Parse JSON
    raw_data = try
        JSON3.read(request_body, Dict{Symbol,Any})
    catch e
        return (status = 400, body = Dict("error" => "Invalid JSON"))
    end

    # Validate request
    ok, result = try_model_validate(CreateUserRequest, raw_data)

    if ok
        # In real app: save to database, send email, etc.
        user = result
        return (
            status = 201,
            body = Dict(
                "message" => "User created successfully",
                "username" => user.username,
                "email" => user.email
            )
        )
    else
        # Return validation errors
        return (
            status = 422,
            body = Dict(
                "error" => "Validation failed",
                "details" => [
                    Dict(
                        "field" => join(err.path, "."),
                        "code" => string(err.code),
                        "message" => err.message
                    )
                    for err in result.errors
                ]
            )
        )
    end
end

# Test with valid request
valid_request = """
{
    "username": "alice_dev",
    "email": "alice@example.com",
    "password": "SecurePass123!",
    "full_name": "Alice Developer",
    "age": 28,
    "newsletter_opt_in": true
}
"""

response = handle_user_registration(valid_request)
println("Valid request:")
println("  Status: $(response.status)")
println("  Body: $(response.body)")
println()

# Test with invalid request
invalid_request = """
{
    "username": "ab",
    "email": "not-an-email",
    "password": "short",
    "full_name": "Bob"
}
"""

response = handle_user_registration(invalid_request)
println("Invalid request:")
println("  Status: $(response.status)")
println("  Error: $(response.body["error"])")
println("  Validation errors:")
for detail in response.body["details"]
    println("    - $(detail["field"]): $(detail["message"])")
end
println()

# ============================================================================
# Use Case 2: Configuration File Validation
# ============================================================================

println("=" ^ 80)
println("Use Case 2: Configuration File Validation")
println("=" ^ 80)
println()

@model Base.@kwdef struct DatabaseConfig
    host::String
    port::Int
    database::String
    username::String
    password::String
    pool_size::Int = 10
    timeout_seconds::Int = 30
end

@rules DatabaseConfig begin
    field(:host, minlen(1))
    field(:port, ge(1), le(65535))
    field(:database, minlen(1))
    field(:username, minlen(1))
    field(:password, minlen(1), secret())
    field(:pool_size, ge(1), le(100))
    field(:timeout_seconds, ge(1), le(300))
end

@model Base.@kwdef struct AppConfig
    app_name::String
    environment::String
    debug::Bool = false
    database::DatabaseConfig
    allowed_origins::Vector{String} = String[]
end

@rules AppConfig begin
    field(:app_name, minlen(1))
    field(:environment, choices(["development", "staging", "production"]))
    field(:allowed_origins, each(url()))
end

function load_config(config_json::String)
    raw_config = try
        JSON3.read(config_json, Dict{Symbol,Any})
    catch e
        error("Failed to parse config file: $(e)")
    end

    ok, result = try_model_validate(AppConfig, raw_config)

    if ok
        println("✓ Configuration loaded successfully")
        println("  App: $(result.app_name)")
        println("  Environment: $(result.environment)")
        println("  Database: $(result.database.host):$(result.database.port)")
        return result
    else
        println("✗ Configuration validation failed:")
        for err in result.errors
            println("  - $(join(err.path, ".")): $(err.message)")
        end
        error("Invalid configuration")
    end
end

# Valid config
valid_config = """
{
    "app_name": "MyWebApp",
    "environment": "production",
    "debug": false,
    "database": {
        "host": "db.example.com",
        "port": 5432,
        "database": "myapp_prod",
        "username": "app_user",
        "password": "secret123",
        "pool_size": 20,
        "timeout_seconds": 60
    },
    "allowed_origins": [
        "https://app.example.com",
        "https://www.example.com"
    ]
}
"""

config = load_config(valid_config)
println()

# ============================================================================
# Use Case 3: E-commerce Order Processing
# ============================================================================

println("=" ^ 80)
println("Use Case 3: E-commerce Order Processing")
println("=" ^ 80)
println()

@model struct OrderItem
    product_id::String
    quantity::Int
    unit_price::Float64
end

@rules OrderItem begin
    field(:product_id, uuid())
    field(:quantity, ge(1), le(1000))
    field(:unit_price, gt(0.0))
end

@model struct ShippingAddress
    recipient_name::String
    street::String
    city::String
    state::String
    zipcode::String
    country::String
    phone::String
end

@rules ShippingAddress begin
    field(:recipient_name, minlen(1))
    field(:street, minlen(5))
    field(:city, minlen(1))
    field(:state, minlen(2), maxlen(2))
    field(:zipcode, regex(r"^\d{5}(-\d{4})?$"))
    field(:country, choices(["USA", "CAN", "MEX"]))
    field(:phone, regex(r"^\+?1?\d{10,14}$"))
end

@model Base.@kwdef struct CreateOrderRequest
    customer_id::String
    items::Vector{OrderItem}
    shipping_address::ShippingAddress
    payment_method::String
    promo_code::Union{Nothing,String} = nothing
end

@rules CreateOrderRequest begin
    field(:customer_id, uuid())
    field(:items, minlen(1), maxlen(100))
    field(:payment_method, choices(["credit_card", "debit_card", "paypal"]))
    field(:promo_code, minlen(4), maxlen(20))
end

function calculate_order_total(items::Vector{OrderItem})
    sum(item.quantity * item.unit_price for item in items)
end

function process_order(order_json::String)
    raw_order = JSON3.read(order_json, Dict{Symbol,Any})

    ok, result = try_model_validate(CreateOrderRequest, raw_order)

    if ok
        order = result
        total = calculate_order_total(order.items)

        println("✓ Order processed successfully")
        println("  Customer ID: $(order.customer_id)")
        println("  Items: $(length(order.items))")
        println("  Total: \$$(round(total, digits=2))")
        println("  Shipping to: $(order.shipping_address.city), $(order.shipping_address.state)")
        println("  Payment: $(order.payment_method)")
        if !isnothing(order.promo_code)
            println("  Promo code: $(order.promo_code)")
        end

        return (success = true, order_id = "ORD-" * string(abs(rand(Int32))))
    else
        println("✗ Order validation failed:")
        for err in result.errors
            println("  - $(join(err.path, ".")): $(err.message)")
        end
        return (success = false, errors = result.errors)
    end
end

# Valid order
valid_order = """
{
    "customer_id": "550e8400-e29b-41d4-a716-446655440000",
    "items": [
        {
            "product_id": "650e8400-e29b-41d4-a716-446655440001",
            "quantity": 2,
            "unit_price": 29.99
        },
        {
            "product_id": "650e8400-e29b-41d4-a716-446655440002",
            "quantity": 1,
            "unit_price": 49.99
        }
    ],
    "shipping_address": {
        "recipient_name": "John Doe",
        "street": "123 Main Street",
        "city": "Boston",
        "state": "MA",
        "zipcode": "02101",
        "country": "USA",
        "phone": "+11234567890"
    },
    "payment_method": "credit_card",
    "promo_code": "SUMMER2024"
}
"""

result = process_order(valid_order)
println()

# ============================================================================
# Use Case 4: Data Import/ETL Pipeline
# ============================================================================

println("=" ^ 80)
println("Use Case 4: Data Import/ETL Pipeline")
println("=" ^ 80)
println()

@model struct SalesRecord
    date::String  # In real app: Date type with custom parser
    sales_rep_id::String
    customer_email::String
    amount::Float64
    region::String
    product_category::String
end

@rules SalesRecord begin
    field(:date, regex(r"^\d{4}-\d{2}-\d{2}$"))  # YYYY-MM-DD
    field(:sales_rep_id, regex(r"^SR\d{6}$"))     # SR followed by 6 digits
    field(:customer_email, email())
    field(:amount, gt(0.0), le(1000000.0))
    field(:region, choices(["North", "South", "East", "West"]))
    field(:product_category, minlen(1))
end

function import_sales_data(records::Vector{Dict{Symbol,Any}})
    valid_records = []
    invalid_records = []

    for (i, record) in enumerate(records)
        ok, result = try_model_validate(SalesRecord, record)

        if ok
            push!(valid_records, result)
        else
            push!(invalid_records, (
                row = i,
                data = record,
                errors = result.errors
            ))
        end
    end

    println("Import summary:")
    println("  Total records: $(length(records))")
    println("  Valid: $(length(valid_records))")
    println("  Invalid: $(length(invalid_records))")

    if !isempty(invalid_records)
        println()
        println("Invalid records:")
        for inv in invalid_records
            println("  Row $(inv.row):")
            for err in inv.errors
                println("    - $(join(err.path, ".")): $(err.message)")
            end
        end
    end

    return (valid = valid_records, invalid = invalid_records)
end

# Sample data import
sample_records = [
    Dict(:date => "2024-01-15", :sales_rep_id => "SR123456",
         :customer_email => "customer1@example.com", :amount => 1299.99,
         :region => "North", :product_category => "Electronics"),

    Dict(:date => "2024-01-16", :sales_rep_id => "SR123457",
         :customer_email => "invalid-email", :amount => 599.99,  # Invalid email
         :region => "South", :product_category => "Furniture"),

    Dict(:date => "2024-01-17", :sales_rep_id => "SR123458",
         :customer_email => "customer3@example.com", :amount => 299.99,
         :region => "East", :product_category => "Books"),
]

import_result = import_sales_data(sample_records)
println()

println("=" ^ 80)
println("Tip: BoundaryTypes.jl excels at validating external data at system boundaries!")
println("=" ^ 80)
