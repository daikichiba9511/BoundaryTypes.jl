using Test
using BoundaryTypes

@model Base.@kwdef struct Signup
    email::String
    password::String
    age::Int = 0
end

@rules Signup begin
    field(:email, regex(r"@"))
    field(:password, minlen(12), regex(r"[0-9]"), secret())
    field(:age, ge(0), le(150))
end

@testset "BoundaryTypes basic" begin
    # success
    s = BoundaryTypes.model_validate(Signup, Dict("email"=>"a@b", "password"=>"A23456789012", "age"=>10))
    @test s.age == 10

    # default validated
    s2 = BoundaryTypes.model_validate(Signup, Dict("email"=>"a@b", "password"=>"A23456789012"))
    @test s2.age == 0

    # aggregated errors
    ok, err = BoundaryTypes.try_model_validate(Signup, Dict("email"=>"ab", "password"=>"short"))
    @test !ok
    @test err isa BoundaryTypes.ValidationError
    @test length(err.errors) >= 2
    @test any(e.code == :regex && e.path == [:email] for e in err.errors)

    # secret masks got in showerror (smoke)
    io = IOBuffer()
    showerror(io, err)
    @test occursin("***", String(take!(io)))
end

@testset "BoundaryTypes validation errors" begin
    # missing required field (email)
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate(
        Signup,
        Dict("password"=>"ValidPass123", "age"=>25)
    )

    # missing required field (password)
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate(
        Signup,
        Dict("email"=>"test@example.com", "age"=>25)
    )

    # email regex validation failure (no @)
    ok, err = BoundaryTypes.try_model_validate(
        Signup,
        Dict("email"=>"invalidemail", "password"=>"ValidPass123")
    )
    @test !ok
    @test any(e.code == :regex && e.path == [:email] for e in err.errors)

    # password too short (minlen)
    ok, err = BoundaryTypes.try_model_validate(
        Signup,
        Dict("email"=>"test@example.com", "password"=>"Short1")
    )
    @test !ok
    @test any(e.code == :minlen && e.path == [:password] for e in err.errors)

    # password missing number (regex)
    ok, err = BoundaryTypes.try_model_validate(
        Signup,
        Dict("email"=>"test@example.com", "password"=>"NoNumberPassword")
    )
    @test !ok
    @test any(e.code == :regex && e.path == [:password] for e in err.errors)

    # age too low (ge)
    ok, err = BoundaryTypes.try_model_validate(
        Signup,
        Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>-1)
    )
    @test !ok
    @test any(e.code == :ge && e.path == [:age] for e in err.errors)

    # age too high (le)
    ok, err = BoundaryTypes.try_model_validate(
        Signup,
        Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>200)
    )
    @test !ok
    @test any(e.code == :le && e.path == [:age] for e in err.errors)

    # extra field forbidden
    ok, err = BoundaryTypes.try_model_validate(
        Signup,
        Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>25, "extra_field"=>"not allowed")
    )
    @test !ok
    @test any(e.code == :extra && e.path == [:extra_field] for e in err.errors)

    # multiple validation errors at once
    ok, err = BoundaryTypes.try_model_validate(
        Signup,
        Dict("email"=>"noemail", "password"=>"short", "age"=>-5)
    )
    @test !ok
    @test length(err.errors) >= 3
    @test any(e.code == :regex && e.path == [:email] for e in err.errors)
    @test any(e.code == :minlen && e.path == [:password] for e in err.errors)
    @test any(e.code == :ge && e.path == [:age] for e in err.errors)
end

@testset "BoundaryTypes JSON parsing" begin
    # success with JSON string
    json_str = """{"email":"test@example.com", "password":"ValidPass123", "age":25}"""
    s = BoundaryTypes.model_validate_json(Signup, json_str)
    @test s.email == "test@example.com"
    @test s.age == 25

    # JSON with default value (age missing)
    json_str2 = """{"email":"user@test.com", "password":"SecurePass456"}"""
    s2 = BoundaryTypes.model_validate_json(Signup, json_str2)
    @test s2.age == 0

    # JSON validation error - email regex failure
    json_str3 = """{"email":"invalid", "password":"short"}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(Signup, json_str3)

    # JSON validation error - missing required field
    json_str4 = """{"email":"test@example.com"}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(Signup, json_str4)

    # JSON validation error - age out of range
    json_str5 = """{"email":"test@example.com", "password":"ValidPass123", "age":999}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(Signup, json_str5)

    # JSON with extra field
    json_str6 = """{"email":"test@example.com", "password":"ValidPass123", "age":25, "unexpected":"field"}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(Signup, json_str6)
end

@testset "Type mismatch errors" begin
    # email should be String, not Int
    ok, err = try_model_validate(Signup, Dict("email"=>12345, "password"=>"ValidPass123", "age"=>25))
    @test !ok
    @test any(e.code == :type && e.path == [:email] for e in err.errors)
    @test any(e -> e.code == :type && occursin("expected String", e.message), err.errors)

    # password should be String, not Int
    ok, err = try_model_validate(Signup, Dict("email"=>"test@example.com", "password"=>999, "age"=>25))
    @test !ok
    @test any(e.code == :type && e.path == [:password] for e in err.errors)

    # age should be Int, not String
    ok, err = try_model_validate(Signup, Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>"not a number"))
    @test !ok
    @test any(e.code == :type && e.path == [:age] for e in err.errors)
    @test any(e -> e.code == :type && occursin("expected Int", e.message), err.errors)

    # age should be Int, not Float
    ok, err = try_model_validate(Signup, Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>25.5))
    @test !ok
    @test any(e.code == :type && e.path == [:age] for e in err.errors)

    # multiple type errors
    ok, err = try_model_validate(Signup, Dict("email"=>123, "password"=>456, "age"=>"string"))
    @test !ok
    @test length(err.errors) >= 3
    @test count(e -> e.code == :type, err.errors) >= 3

    # JSON with type mismatch - age as string
    json_type_err = """{"email":"test@example.com", "password":"ValidPass123", "age":"twenty"}"""
    ok, err = try_model_validate_json(Signup, json_type_err)
    @test !ok
    @test any(e.code == :type && e.path == [:age] for e in err.errors)

    # JSON with type mismatch - email as number
    json_type_err2 = """{"email":12345, "password":"ValidPass123", "age":25}"""
    ok, err = try_model_validate_json(Signup, json_type_err2)
    @test !ok
    @test any(e.code == :type && e.path == [:email] for e in err.errors)

    # Test that type error is thrown (not just collected)
    @test_throws ValidationError model_validate(Signup, Dict("email"=>12345, "password"=>"ValidPass123"))
end

@testset "Secret field masking" begin
    # password is marked as secret, so error values should be masked
    ok, err = try_model_validate(Signup, Dict("email"=>"test@example.com", "password"=>"short"))
    @test !ok

    # Find password errors and verify they are masked
    password_errors = filter(e -> e.path == [:password], err.errors)
    @test !isempty(password_errors)
    @test all(e -> e.got == "***", password_errors)

    # Non-secret fields (email, age) should show actual values
    ok, err = try_model_validate(Signup, Dict("email"=>"invalid", "password"=>"ValidPassword123", "age"=>-5))
    @test !ok

    # email is not secret - actual value should be shown
    email_errors = filter(e -> e.path == [:email], err.errors)
    if !isempty(email_errors)
        @test any(e -> e.got == "invalid", email_errors)
    end

    # age is not secret - actual value should be shown
    age_errors = filter(e -> e.path == [:age], err.errors)
    if !isempty(age_errors)
        @test any(e -> e.got == -5, age_errors)
    end

    # showerror should mask secret values
    ok, err = try_model_validate(Signup, Dict("email"=>"test@example.com", "password"=>"MySecret123"))
    @test !ok
    io = IOBuffer()
    showerror(io, err)
    output = String(take!(io))
    @test occursin("***", output)
    @test !occursin("MySecret123", output)  # actual password should not leak

    # Type error on secret field should also be masked
    ok, err = try_model_validate(Signup, Dict("email"=>"test@example.com", "password"=>12345, "age"=>25))
    @test !ok
    password_type_errors = filter(e -> e.path == [:password] && e.code == :type, err.errors)
    @test !isempty(password_type_errors)
    @test all(e -> e.got == "***", password_type_errors)

    # Multiple password errors should all be masked
    ok, err = try_model_validate(Signup, Dict("email"=>"test@example.com", "password"=>"short"))
    @test !ok
    password_all_errors = filter(e -> e.path == [:password], err.errors)
    @test length(password_all_errors) >= 2  # minlen and regex errors
    @test all(e -> e.got == "***", password_all_errors)

    # JSON parsing - secret field should be masked
    json_str = """{"email":"test@example.com", "password":"x"}"""
    ok, err = try_model_validate_json(Signup, json_str)
    @test !ok
    password_json_errors = filter(e -> e.path == [:password], err.errors)
    @test !isempty(password_json_errors)
    @test all(e -> e.got == "***", password_json_errors)
end

@testset "Direct API usage (without BoundaryTypes prefix)" begin
    # model_validate - success
    s = model_validate(Signup, Dict("email"=>"user@example.com", "password"=>"SecurePass123", "age"=>30))
    @test s.email == "user@example.com"
    @test s.password == "SecurePass123"
    @test s.age == 30

    # model_validate - with default value
    s2 = model_validate(Signup, Dict("email"=>"test@test.com", "password"=>"ValidPass456"))
    @test s2.age == 0

    # model_validate - validation error
    @test_throws ValidationError model_validate(Signup, Dict("email"=>"invalid", "password"=>"short"))

    # try_model_validate - success case
    ok, result = try_model_validate(Signup, Dict("email"=>"good@email.com", "password"=>"LongPassword123", "age"=>25))
    @test ok
    @test result isa Signup
    @test result.email == "good@email.com"

    # try_model_validate - failure case
    ok, err = try_model_validate(Signup, Dict("email"=>"bademail", "password"=>"x"))
    @test !ok
    @test err isa ValidationError
    @test length(err.errors) >= 2

    # model_validate_json - success
    json_success = """{"email":"json@example.com", "password":"JsonPassword123", "age":40}"""
    s3 = model_validate_json(Signup, json_success)
    @test s3.email == "json@example.com"
    @test s3.age == 40

    # model_validate_json - with default
    json_default = """{"email":"default@test.com", "password":"DefaultPass123"}"""
    s4 = model_validate_json(Signup, json_default)
    @test s4.age == 0

    # model_validate_json - validation error
    json_invalid = """{"email":"noemail", "password":"short", "age":-10}"""
    @test_throws ValidationError model_validate_json(Signup, json_invalid)

    # Using NamedTuple instead of Dict
    s5 = model_validate(Signup, (email="named@tuple.com", password="NamedTuplePass123", age=50))
    @test s5.email == "named@tuple.com"
    @test s5.age == 50
end

@testset "@validated_model constructor validation" begin
    # Define model with @validated_model
    @validated_model struct Account
        username::String
        email::String
        balance::Float64 = 0.0
    end

    @rules Account begin
        field(:username, minlen(3))
        field(:email, regex(r"@"))
        field(:balance, ge(0.0))
    end

    # Success: valid keyword constructor
    acc = Account(username="alice", email="alice@example.com", balance=100.0)
    @test acc.username == "alice"
    @test acc.email == "alice@example.com"
    @test acc.balance == 100.0

    # Success: with default value
    acc2 = Account(username="bob", email="bob@test.com")
    @test acc2.balance == 0.0

    # Failure: username too short
    @test_throws ValidationError Account(username="ab", email="test@example.com")

    # Failure: email missing @
    @test_throws ValidationError Account(username="charlie", email="invalid")

    # Failure: negative balance
    @test_throws ValidationError Account(username="dave", email="dave@test.com", balance=-10.0)

    # Failure: missing required field
    @test_throws ValidationError Account(username="eve")

    # Multiple validation errors
    try
        Account(username="x", email="noemail", balance=-5.0)
        @test false  # Should not reach here
    catch e
        @test e isa ValidationError
        @test length(e.errors) >= 3
        @test any(err -> err.path == [:username] && err.code == :minlen, e.errors)
        @test any(err -> err.path == [:email] && err.code == :regex, e.errors)
        @test any(err -> err.path == [:balance] && err.code == :ge, e.errors)
    end

    # Test optional fields with @validated_model
    @validated_model struct Profile
        name::String
        bio::Union{Nothing,String} = nothing
    end

    @rules Profile begin
        field(:name, minlen(2))
        field(:bio, minlen(10))  # Only validated when present
    end

    # Success: optional field not provided
    p1 = Profile(name="Alice")
    @test p1.name == "Alice"
    @test p1.bio === nothing

    # Success: optional field provided with valid value
    p2 = Profile(name="Bob", bio="This is a long enough bio")
    @test p2.bio == "This is a long enough bio"

    # Failure: optional field too short
    @test_throws ValidationError Profile(name="Charlie", bio="short")

    # Test that model_validate still works on @validated_model types
    acc3 = model_validate(Account, Dict(:username => "frank", :email => "frank@test.com"))
    @test acc3.username == "frank"
    @test acc3.balance == 0.0

    # Test try_model_validate compatibility
    ok, result = try_model_validate(Account, Dict(:username => "grace", :email => "grace@test.com", :balance => 50.0))
    @test ok
    @test result.username == "grace"
    @test result.balance == 50.0
end

@testset "model_copy and model_copy!" begin
    # Test immutable struct with model_copy
    @model Base.@kwdef struct ImmutableUser
        name::String
        email::String
        age::Int = 0
    end

    @rules ImmutableUser begin
        field(:email, regex(r"@"))
        field(:age, ge(0), le(150))
    end

    user = model_validate(ImmutableUser, Dict(:name => "Alice", :email => "alice@example.com", :age => 25))

    # Update single field
    updated1 = model_copy(user, Dict(:age => 26))
    @test updated1.name == "Alice"
    @test updated1.email == "alice@example.com"
    @test updated1.age == 26
    @test user.age == 25  # Original unchanged

    # Update multiple fields
    updated2 = model_copy(user, Dict(:name => "Alicia", :email => "alicia@example.com"))
    @test updated2.name == "Alicia"
    @test updated2.email == "alicia@example.com"
    @test updated2.age == 25  # Unchanged field preserved

    # Update with NamedTuple
    updated3 = model_copy(user, (age=30,))
    @test updated3.age == 30

    # Validation error on invalid update
    @test_throws ValidationError model_copy(user, Dict(:age => -1))
    @test_throws ValidationError model_copy(user, Dict(:email => "invalid"))

    # Without validation (skip rules)
    updated4 = model_copy(user, Dict(:age => 200); validate=false)
    @test updated4.age == 200  # Validation skipped

    # Test mutable struct with model_copy!
    @model Base.@kwdef mutable struct MutableUser
        name::String
        email::String
        age::Int = 0
    end

    @rules MutableUser begin
        field(:email, regex(r"@"))
        field(:age, ge(0), le(150))
    end

    muser = model_validate(MutableUser, Dict(:name => "Bob", :email => "bob@test.com", :age => 30))

    # In-place update
    result = model_copy!(muser, Dict(:age => 31))
    @test result === muser  # Returns same instance
    @test muser.age == 31

    # Multiple field update
    model_copy!(muser, Dict(:name => "Robert", :email => "robert@test.com"))
    @test muser.name == "Robert"
    @test muser.email == "robert@test.com"

    # Validation error prevents update
    old_age = muser.age
    @test_throws ValidationError model_copy!(muser, Dict(:age => -5))
    @test muser.age == old_age  # Value unchanged due to validation error

    # Without validation
    model_copy!(muser, Dict(:age => 200); validate=false)
    @test muser.age == 200

    # Test error when using model_copy! on immutable struct
    @test_throws ErrorException model_copy!(user, Dict(:age => 50))

    # Test that model_copy works on mutable structs too
    muser2 = model_validate(MutableUser, Dict(:name => "Charlie", :email => "charlie@test.com", :age => 40))
    muser2_copy = model_copy(muser2, Dict(:age => 41))
    @test muser2_copy !== muser2  # Different instances
    @test muser2_copy.age == 41
    @test muser2.age == 40  # Original unchanged

    # Test with @validated_model
    @validated_model struct ValidatedPerson
        name::String
        age::Int = 0
    end

    @rules ValidatedPerson begin
        field(:age, ge(0))
    end

    person = ValidatedPerson(name="Dave", age=50)
    person_updated = model_copy(person, Dict(:age => 51))
    @test person_updated.age == 51
    @test person.age == 50
end

@testset "show_rules" begin
    @testset "Basic show_rules functionality" begin
        @model Base.@kwdef struct ShowRulesTest
            email::String
            password::String
            age::Int = 0
            nickname::Union{Nothing,String} = nothing
        end

        @rules ShowRulesTest begin
            field(:email, regex(r"^[^@\s]+@[^@\s]+\.[^@\s]+$"))
            field(:password, minlen(12), secret())
            field(:age, ge(0), le(150))
            field(:nickname, minlen(3))
        end

        # Test that show_rules doesn't throw
        io = IOBuffer()
        @test_nowarn show_rules(io, ShowRulesTest)

        output = String(take!(io))

        # Verify output contains model name
        @test occursin("ShowRulesTest", output)

        # Verify output contains all field names
        @test occursin("email", output)
        @test occursin("password", output)
        @test occursin("age", output)
        @test occursin("nickname", output)

        # Verify output shows field types
        @test occursin("String", output)
        @test occursin("Int", output)

        # Verify output shows attributes
        @test occursin("required", output) || occursin("Required", output)
        @test occursin("optional", output) || occursin("Optional", output)
        @test occursin("default", output) || occursin("Default", output)
        @test occursin("secret", output) || occursin("Secret", output)

        # Verify output shows rule names
        @test occursin("regex", output)
        @test occursin("minlen", output)
        @test occursin("ge", output)
        @test occursin("le", output)
    end

    @testset "show_rules with unregistered type" begin
        struct UnregisteredType
            x::Int
        end

        io = IOBuffer()
        @test_nowarn show_rules(io, UnregisteredType)

        output = String(take!(io))
        @test occursin("No rules registered", output)
    end

    @testset "show_rules with minimal model" begin
        @model struct MinimalModel
            x::Int
        end

        io = IOBuffer()
        @test_nowarn show_rules(io, MinimalModel)

        output = String(take!(io))
        @test occursin("MinimalModel", output)
        @test occursin("x", output)
        @test occursin("Int", output)
    end

    @testset "show_rules with validated_model" begin
        @validated_model struct ValidatedRulesTest
            username::String
            email::String
        end

        @rules ValidatedRulesTest begin
            field(:username, minlen(3))
            field(:email, regex(r"@"))
        end

        io = IOBuffer()
        @test_nowarn show_rules(io, ValidatedRulesTest)

        output = String(take!(io))
        @test occursin("ValidatedRulesTest", output)
        @test occursin("username", output)
        @test occursin("email", output)
        @test occursin("minlen", output)
        @test occursin("regex", output)
    end

    @testset "show_rules defaults to stdout" begin
        @model struct StdoutTest
            x::Int
        end

        # Test that single-argument version doesn't throw
        # (we can't easily capture stdout in tests, but we can verify it doesn't error)
        @test_nowarn show_rules(StdoutTest)
    end
end

@testset "Nested struct validation" begin
    @testset "Basic nested validation" begin
        @model struct Address
            city::String
            zipcode::String
        end

        @rules Address begin
            field(:city, minlen(1))
            field(:zipcode, regex(r"^\d{5}$"))
        end

        @model struct Person
            name::String
            address::Address
        end

        @rules Person begin
            field(:name, minlen(2))
        end

        # Success: valid nested data
        person = model_validate(Person, Dict(
            :name => "Alice",
            :address => Dict(:city => "Tokyo", :zipcode => "12345")
        ))
        @test person.name == "Alice"
        @test person.address isa Address
        @test person.address.city == "Tokyo"
        @test person.address.zipcode == "12345"

        # Failure: nested field validation error (zipcode invalid)
        ok, err = try_model_validate(Person, Dict(
            :name => "Bob",
            :address => Dict(:city => "Osaka", :zipcode => "abc")
        ))
        @test !ok
        @test err isa ValidationError
        @test any(e -> e.path == [:address, :zipcode] && e.code == :regex, err.errors)

        # Failure: nested field missing
        ok, err = try_model_validate(Person, Dict(
            :name => "Charlie",
            :address => Dict(:city => "Kyoto")
        ))
        @test !ok
        @test any(e -> e.path == [:address, :zipcode] && e.code == :missing, err.errors)

        # Failure: multiple nested errors
        ok, err = try_model_validate(Person, Dict(
            :name => "D",  # too short
            :address => Dict(:city => "", :zipcode => "invalid")  # city too short, zipcode invalid
        ))
        @test !ok
        @test length(err.errors) >= 3
        @test any(e -> e.path == [:name] && e.code == :minlen, err.errors)
        @test any(e -> e.path == [:address, :city] && e.code == :minlen, err.errors)
        @test any(e -> e.path == [:address, :zipcode] && e.code == :regex, err.errors)
    end

    @testset "Multiple level nesting" begin
        @model struct Country
            name::String
            code::String
        end

        @rules Country begin
            field(:code, regex(r"^[A-Z]{2}$"))
        end

        @model struct City
            name::String
            country::Country
        end

        @model struct Office
            address::String
            city::City
        end

        # Success: deeply nested validation
        office = model_validate(Office, Dict(
            :address => "123 Main St",
            :city => Dict(
                :name => "Tokyo",
                :country => Dict(:name => "Japan", :code => "JP")
            )
        ))
        @test office.address == "123 Main St"
        @test office.city.name == "Tokyo"
        @test office.city.country.name == "Japan"
        @test office.city.country.code == "JP"

        # Failure: deeply nested validation error
        ok, err = try_model_validate(Office, Dict(
            :address => "456 Elm St",
            :city => Dict(
                :name => "London",
                :country => Dict(:name => "United Kingdom", :code => "GBR")  # should be 2 chars
            )
        ))
        @test !ok
        @test any(e -> e.path == [:city, :country, :code] && e.code == :regex, err.errors)
    end

    @testset "Optional nested fields" begin
        @model Base.@kwdef struct ContactInfo
            email::String
            phone::Union{Nothing,String} = nothing
        end

        @rules ContactInfo begin
            field(:email, regex(r"@"))
            field(:phone, regex(r"^\d{10}$"))
        end

        @model Base.@kwdef struct User
            name::String
            contact::Union{Nothing,ContactInfo} = nothing
        end

        # Success: optional nested field not provided
        user1 = model_validate(User, Dict(:name => "Alice"))
        @test user1.contact === nothing

        # Success: optional nested field provided
        user2 = model_validate(User, Dict(
            :name => "Bob",
            :contact => Dict(:email => "bob@example.com")
        ))
        @test user2.contact isa ContactInfo
        @test user2.contact.email == "bob@example.com"
        @test user2.contact.phone === nothing

        # Failure: optional nested field with invalid data
        ok, err = try_model_validate(User, Dict(
            :name => "Charlie",
            :contact => Dict(:email => "invalid-email")
        ))
        @test !ok
        @test any(e -> e.path == [:contact, :email] && e.code == :regex, err.errors)
    end

    @testset "Nested with defaults" begin
        @model Base.@kwdef struct Settings
            theme::String = "light"
            fontSize::Int = 14
        end

        @rules Settings begin
            field(:fontSize, ge(8), le(72))
        end

        @model Base.@kwdef struct AppConfig
            appName::String
            settings::Settings = Settings()
        end

        # Success: using default nested struct
        config1 = model_validate(AppConfig, Dict(:appName => "MyApp"))
        @test config1.settings.theme == "light"
        @test config1.settings.fontSize == 14

        # Success: partial override of nested struct
        config2 = model_validate(AppConfig, Dict(
            :appName => "MyApp",
            :settings => Dict(:fontSize => 20)
        ))
        @test config2.settings.theme == "light"
        @test config2.settings.fontSize == 20

        # Failure: invalid nested field value
        ok, err = try_model_validate(AppConfig, Dict(
            :appName => "MyApp",
            :settings => Dict(:fontSize => 100)  # too large
        ))
        @test !ok
        @test any(e -> e.path == [:settings, :fontSize] && e.code == :le, err.errors)
    end

    @testset "Nested with NamedTuple input" begin
        @model struct Coords
            lat::Float64
            lon::Float64
        end

        @rules Coords begin
            field(:lat, ge(-90.0), le(90.0))
            field(:lon, ge(-180.0), le(180.0))
        end

        @model struct Location
            name::String
            coords::Coords
        end

        # Success: NamedTuple input for nested model
        location = model_validate(Location, (
            name="Tokyo Tower",
            coords=(lat=35.6586, lon=139.7454)
        ))
        @test location.name == "Tokyo Tower"
        @test location.coords.lat ≈ 35.6586
        @test location.coords.lon ≈ 139.7454
    end

    @testset "Nested extra field handling" begin
        @model struct BasicInfo
            id::Int
            value::String
        end

        @model struct Container
            data::BasicInfo
        end

        # Failure: extra field in nested model
        ok, err = try_model_validate(Container, Dict(
            :data => Dict(:id => 1, :value => "test", :extra => "not allowed")
        ))
        @test !ok
        @test any(e -> e.path == [:data, :extra] && e.code == :extra, err.errors)
    end

    @testset "Nested type errors" begin
        @model struct TypedNested
            count::Int
        end

        @model struct TypedContainer
            nested::TypedNested
        end

        # Failure: wrong type for nested field value
        ok, err = try_model_validate(TypedContainer, Dict(
            :nested => Dict(:count => "not a number")
        ))
        @test !ok
        @test any(e -> e.path == [:nested, :count] && e.code == :type, err.errors)

        # Failure: wrong type for nested model itself
        ok, err = try_model_validate(TypedContainer, Dict(
            :nested => "not a dict"
        ))
        @test !ok
        @test any(e -> e.path == [:nested] && e.code == :type, err.errors)
    end
end

@testset "JSON Schema generation" begin
    @testset "Basic schema generation" begin
        @model Base.@kwdef struct SchemaTest
            email::String
            password::String
            age::Int = 0
            nickname::Union{Nothing,String} = nothing
        end

        @rules SchemaTest begin
            field(:email, regex(r"@"))
            field(:password, minlen(12), secret())
            field(:age, ge(0), le(150))
            field(:nickname, minlen(3))
        end

        json_schema = schema(SchemaTest)

        # Check root structure
        @test json_schema["\$schema"] == "http://json-schema.org/draft-07/schema#"
        @test json_schema["type"] == "object"
        @test haskey(json_schema, "properties")
        @test haskey(json_schema, "required")
        @test json_schema["additionalProperties"] == false

        # Check required fields
        @test "email" in json_schema["required"]
        @test "password" in json_schema["required"]
        @test !("age" in json_schema["required"])  # Has default
        @test !("nickname" in json_schema["required"])  # Optional

        # Check properties
        props = json_schema["properties"]

        # Email field
        @test haskey(props, "email")
        @test props["email"]["type"] == "string"

        # Password field
        @test haskey(props, "password")
        @test props["password"]["type"] == "string"
        @test props["password"]["minLength"] == 12
        @test haskey(props["password"], "description")
        @test occursin("Secret", props["password"]["description"])

        # Age field
        @test haskey(props, "age")
        @test props["age"]["type"] == "integer"
        @test props["age"]["minimum"] == 0
        @test props["age"]["maximum"] == 150
        @test props["age"]["default"] == 0

        # Nickname field
        @test haskey(props, "nickname")
        @test props["nickname"]["type"] == "string"
        @test props["nickname"]["minLength"] == 3
    end

    @testset "Schema with minimal model" begin
        @model struct MinimalSchema
            x::Int
        end

        json_schema = schema(MinimalSchema)

        @test json_schema["type"] == "object"
        @test haskey(json_schema, "properties")
        @test haskey(json_schema["properties"], "x")
        @test json_schema["properties"]["x"]["type"] == "integer"
        @test json_schema["required"] == ["x"]
    end

    @testset "Schema with no required fields" begin
        @model Base.@kwdef struct AllOptional
            x::Int = 0
            y::Union{Nothing,String} = nothing
        end

        json_schema = schema(AllOptional)

        @test json_schema["type"] == "object"
        @test !haskey(json_schema, "required") || isempty(json_schema["required"])
        @test json_schema["properties"]["x"]["default"] == 0
    end

    @testset "Schema type mapping" begin
        @model struct TypeMapping
            str::String
            int::Int
            float::Float64
            bool::Bool
        end

        json_schema = schema(TypeMapping)
        props = json_schema["properties"]

        @test props["str"]["type"] == "string"
        @test props["int"]["type"] == "integer"
        @test props["float"]["type"] == "number"
        @test props["bool"]["type"] == "boolean"
    end

    @testset "Schema with validated_model" begin
        @validated_model struct ValidatedSchema
            username::String
            email::String
        end

        @rules ValidatedSchema begin
            field(:username, minlen(3))
            field(:email, regex(r"@"))
        end

        json_schema = schema(ValidatedSchema)

        @test json_schema["type"] == "object"
        @test haskey(json_schema, "properties")
        @test json_schema["properties"]["username"]["minLength"] == 3
        @test json_schema["required"] == ["email", "username"]
    end

    @testset "Schema with unregistered type" begin
        struct UnregisteredSchema
            x::Int
        end

        @test_throws ArgumentError schema(UnregisteredSchema)
    end

    @testset "Schema with multiple rules on same field" begin
        @model struct MultiRuleSchema
            value::Int
        end

        @rules MultiRuleSchema begin
            field(:value, ge(10), le(100))
        end

        json_schema = schema(MultiRuleSchema)
        props = json_schema["properties"]

        @test props["value"]["minimum"] == 10
        @test props["value"]["maximum"] == 100
    end

    @testset "Schema default value types" begin
        @model Base.@kwdef struct DefaultValues
            count::Int = 42
            rate::Float64 = 3.14
            flag::Bool = true
            name::String = "default"
        end

        json_schema = schema(DefaultValues)
        props = json_schema["properties"]

        @test props["count"]["default"] == 42
        @test props["rate"]["default"] == 3.14
        @test props["flag"]["default"] == true
        @test props["name"]["default"] == "default"
    end
end
