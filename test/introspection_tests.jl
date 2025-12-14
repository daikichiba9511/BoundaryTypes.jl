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
