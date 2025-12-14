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
