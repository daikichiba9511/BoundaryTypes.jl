using Test
using BoundaryTypes

@testset "Helper Functions Tests" begin
    @testset "available_rules()" begin
        # Test that available_rules() returns without error
        buf = IOBuffer()
        available_rules(io=buf)
        output = String(take!(buf))

        # Check that output contains expected content
        @test occursin("Available Validation Rules", output)
        @test occursin("String Rules", output)
        @test occursin("Numeric Rules", output)
        @test occursin("Collection Rules", output)
        @test occursin("Other Rules", output)

        # Check that all rules are listed
        @test occursin("minlen", output)
        @test occursin("maxlen", output)
        @test occursin("regex", output)
        @test occursin("email", output)
        @test occursin("url", output)
        @test occursin("uuid", output)
        @test occursin("choices", output)
        @test occursin("ge", output)
        @test occursin("le", output)
        @test occursin("gt", output)
        @test occursin("lt", output)
        @test occursin("between", output)
        @test occursin("multiple_of", output)
        @test occursin("each", output)
        @test occursin("present", output)
        @test occursin("notnothing", output)
        @test occursin("secret", output)
        @test occursin("custom", output)
    end

    @testset "available_rules() with category filter" begin
        # Test string rules filter
        buf = IOBuffer()
        available_rules(io=buf, category=:string)
        output = String(take!(buf))

        @test occursin("String Rules", output)
        @test occursin("minlen", output)
        @test occursin("email", output)
        @test !occursin("Numeric Rules", output)
        # Note: Footer may contain rule names, so we check for absence of numeric section
        @test !occursin("Greater than or equal", output)

        # Test numeric rules filter
        buf = IOBuffer()
        available_rules(io=buf, category=:numeric)
        output = String(take!(buf))

        @test occursin("Numeric Rules", output)
        @test occursin("Greater than or equal", output)
        @test occursin("between", output)
        @test !occursin("String Rules", output)
        @test !occursin("Minimum string/collection length", output)

        # Test collection rules filter
        buf = IOBuffer()
        available_rules(io=buf, category=:collection)
        output = String(take!(buf))

        @test occursin("Collection Rules", output)
        @test occursin("each", output)
        @test !occursin("String Rules", output)

        # Test other rules filter
        buf = IOBuffer()
        available_rules(io=buf, category=:other)
        output = String(take!(buf))

        @test occursin("Other Rules", output)
        @test occursin("present", output)
        @test occursin("secret", output)
        @test !occursin("String Rules", output)
    end

    @testset "string_rules()" begin
        buf = IOBuffer()
        string_rules(io=buf)
        output = String(take!(buf))

        @test occursin("String Rules", output)
        @test occursin("minlen", output)
        @test occursin("maxlen", output)
        @test occursin("regex", output)
        @test occursin("email", output)
        @test occursin("url", output)
        @test occursin("uuid", output)
        @test occursin("choices", output)

        # Should not contain numeric rules description
        @test !occursin("Greater than or equal", output)
        @test !occursin("Range validation", output)
    end

    @testset "numeric_rules()" begin
        buf = IOBuffer()
        numeric_rules(io=buf)
        output = String(take!(buf))

        @test occursin("Numeric Rules", output)
        @test occursin("Greater than or equal", output)
        @test occursin("Less than or equal", output)
        @test occursin("Strictly greater than", output)
        @test occursin("Strictly less than", output)
        @test occursin("between", output)
        @test occursin("multiple_of", output)

        # Should not contain string rules description
        @test !occursin("Minimum string/collection length", output)
        @test !occursin("Email address format", output)
    end

    @testset "collection_rules()" begin
        buf = IOBuffer()
        collection_rules(io=buf)
        output = String(take!(buf))

        @test occursin("Collection Rules", output)
        @test occursin("each", output)

        # Should not contain other rule descriptions
        @test !occursin("Minimum string/collection length", output)
        @test !occursin("Greater than or equal", output)
    end

    @testset "show_rule_examples()" begin
        buf = IOBuffer()
        show_rule_examples(io=buf)
        output = String(take!(buf))

        @test occursin("Validation Rule Examples", output)
        @test occursin("String Validation", output)
        @test occursin("Numeric", output)
        @test occursin("Collection", output)

        # Check that examples contain actual code
        @test occursin("@model", output)
        @test occursin("@rules", output)
        @test occursin("field(", output)
    end

    @testset "Helper functions work with actual validation" begin
        # This test ensures that the rules referenced in helper functions actually work

        @model struct TestUser
            email::String
            age::Int
            tags::Vector{String}
        end

        @rules TestUser begin
            field(:email, email())
            field(:age, ge(0), le(150))
            field(:tags, each(minlen(3)))
        end

        # Valid case
        user = model_validate(TestUser, Dict(
            :email => "test@example.com",
            :age => 25,
            :tags => ["julia", "programming"]
        ))
        @test user.email == "test@example.com"
        @test user.age == 25
        @test user.tags == ["julia", "programming"]

        # Invalid email (rule from string_rules)
        ok, result = try_model_validate(TestUser, Dict(
            :email => "invalid",
            :age => 25,
            :tags => ["julia"]
        ))
        @test !ok
        @test result isa ValidationError

        # Invalid age (rule from numeric_rules)
        ok, result = try_model_validate(TestUser, Dict(
            :email => "test@example.com",
            :age => -5,
            :tags => ["julia"]
        ))
        @test !ok
        @test result isa ValidationError

        # Invalid collection element (rule from collection_rules)
        ok, result = try_model_validate(TestUser, Dict(
            :email => "test@example.com",
            :age => 25,
            :tags => ["ab"]  # Too short
        ))
        @test !ok
        @test result isa ValidationError
    end
end
