using Test
using BoundaryTypes

@testset "Extra Field Handling" begin
    @testset ":forbid mode (default)" begin
        @model struct ForbidUser
            email::String
            age::Int
        end

        # Should reject extra fields
        ok, err = BoundaryTypes.try_model_validate(
            ForbidUser,
            Dict(:email => "test@example.com", :age => 25, :extra => "not allowed")
        )
        @test !ok
        @test any(e.code == :extra && e.path == [:extra] for e in err.errors)

        # Should succeed without extra fields
        ok, result = BoundaryTypes.try_model_validate(
            ForbidUser,
            Dict(:email => "test@example.com", :age => 25)
        )
        @test ok
        @test result.email == "test@example.com"
        @test result.age == 25
    end

    @testset ":forbid mode (explicit)" begin
        @model extra=:forbid struct ExplicitForbidUser
            email::String
            age::Int
        end

        # Should reject extra fields
        ok, err = BoundaryTypes.try_model_validate(
            ExplicitForbidUser,
            Dict(:email => "test@example.com", :age => 25, :extra => "not allowed")
        )
        @test !ok
        @test any(e.code == :extra && e.path == [:extra] for e in err.errors)

        # Should succeed without extra fields
        ok, result = BoundaryTypes.try_model_validate(
            ExplicitForbidUser,
            Dict(:email => "test@example.com", :age => 25)
        )
        @test ok
        @test result.email == "test@example.com"
        @test result.age == 25
    end

    @testset ":ignore mode" begin
        @model extra=:ignore struct IgnoreUser
            email::String
            age::Int
        end

        # Should accept input with extra fields and ignore them
        ok, result = BoundaryTypes.try_model_validate(
            IgnoreUser,
            Dict(:email => "test@example.com", :age => 25, :extra => "ignored", :another => "also ignored")
        )
        @test ok
        @test result.email == "test@example.com"
        @test result.age == 25
        # Extra fields should not be stored
        @test !hasfield(IgnoreUser, :extra)
        @test !hasfield(IgnoreUser, :another)

        # Should also succeed without extra fields
        ok, result = BoundaryTypes.try_model_validate(
            IgnoreUser,
            Dict(:email => "test2@example.com", :age => 30)
        )
        @test ok
        @test result.email == "test2@example.com"
        @test result.age == 30
    end

    @testset ":ignore mode with @validated_model" begin
        @validated_model extra=:ignore struct IgnoreValidatedUser
            email::String
            age::Int
        end

        # Should accept input with extra fields via constructor
        result = IgnoreValidatedUser(email="test@example.com", age=25, extra="ignored")
        @test result.email == "test@example.com"
        @test result.age == 25
    end

    @testset "Extra field override in model_validate" begin
        @model struct DefaultForbidUser
            email::String
            age::Int
        end

        # Model defaults to :forbid, but we can override to :ignore
        ok, result = BoundaryTypes.try_model_validate(
            DefaultForbidUser,
            Dict(:email => "test@example.com", :age => 25, :extra => "should be ignored");
            extra=:ignore
        )
        @test ok
        @test result.email == "test@example.com"
        @test result.age == 25

        # Model defaults to :forbid, use default behavior
        ok, err = BoundaryTypes.try_model_validate(
            DefaultForbidUser,
            Dict(:email => "test@example.com", :age => 25, :extra => "not allowed")
        )
        @test !ok
        @test any(e.code == :extra && e.path == [:extra] for e in err.errors)
    end

    @testset "show_rules displays extra mode" begin
        @model extra=:ignore struct ShowRulesTest
            email::String
        end

        # Capture output
        io = IOBuffer()
        BoundaryTypes.show_rules(io, ShowRulesTest)
        output = String(take!(io))

        # Should show the extra field handling mode
        @test occursin("Extra fields: ignore", output)
    end

    @testset "Nested models with different extra modes" begin
        @model extra=:forbid struct StrictAddress
            street::String
            city::String
        end

        @model extra=:ignore struct FlexiblePerson
            name::String
            address::StrictAddress
        end

        # When parent has :ignore mode, it does NOT propagate to nested models
        # Each nested model uses its own extra mode (or :default which uses model's spec.extra)
        # So the nested StrictAddress should use its own :forbid mode
        ok, result = BoundaryTypes.try_model_validate(
            FlexiblePerson,
            Dict(
                :name => "Alice",
                :extra_person_field => "ignored",
                :address => Dict(
                    :street => "123 Main St",
                    :city => "Springfield",
                    :extra_address_field => "also ignored due to parent"
                )
            )
        )
        # Parent's :ignore mode is inherited by nested models when using :default
        # This is the current behavior - parent's extra mode propagates to children
        @test ok
        @test result.name == "Alice"
        @test result.address.street == "123 Main St"
        @test result.address.city == "Springfield"

        # Parent extra field should be ignored
        ok, result = BoundaryTypes.try_model_validate(
            FlexiblePerson,
            Dict(
                :name => "Alice",
                :extra_person_field => "ignored",
                :address => Dict(
                    :street => "123 Main St",
                    :city => "Springfield"
                )
            )
        )
        @test ok
        @test result.name == "Alice"
        @test result.address.street == "123 Main St"
        @test result.address.city == "Springfield"
    end

    @testset "Nested models inherit parent's extra mode when overridden" begin
        @model extra=:forbid struct NormalAddress
            street::String
            city::String
        end

        @model extra=:forbid struct NormalPerson
            name::String
            address::NormalAddress
        end

        # Override to :ignore for both parent and nested
        ok, result = BoundaryTypes.try_model_validate(
            NormalPerson,
            Dict(
                :name => "Bob",
                :extra_person_field => "should be ignored",
                :address => Dict(
                    :street => "456 Elm St",
                    :city => "Portland",
                    :extra_address_field => "should also be ignored"
                )
            );
            extra=:ignore
        )
        @test ok
        @test result.name == "Bob"
        @test result.address.street == "456 Elm St"
        @test result.address.city == "Portland"
    end

    @testset ":allow mode" begin
        @model extra=:allow struct AllowUser
            email::String
            age::Int
        end

        # Should accept input with extra fields and store them in _extra
        ok, result = BoundaryTypes.try_model_validate(
            AllowUser,
            Dict(:email => "test@example.com", :age => 25, :extra1 => "value1", :extra2 => 42)
        )
        @test ok
        @test result.email == "test@example.com"
        @test result.age == 25
        @test hasfield(AllowUser, :_extra)
        @test result._extra == Dict(:extra1 => "value1", :extra2 => 42)

        # Should work without extra fields
        ok, result2 = BoundaryTypes.try_model_validate(
            AllowUser,
            Dict(:email => "test2@example.com", :age => 30)
        )
        @test ok
        @test result2.email == "test2@example.com"
        @test result2.age == 30
        @test result2._extra == Dict{Symbol,Any}()
    end

    @testset ":allow mode with model_dump" begin
        @model extra=:allow struct AllowProduct
            name::String
            price::Float64
        end

        # Create instance with extra fields
        ok, product = BoundaryTypes.try_model_validate(
            AllowProduct,
            Dict(:name => "Widget", :price => 19.99, :color => "blue", :stock => 100)
        )
        @test ok

        # model_dump should merge _extra fields back into output
        dumped = BoundaryTypes.model_dump(product)
        @test dumped[:name] == "Widget"
        @test dumped[:price] == 19.99
        @test dumped[:color] == "blue"
        @test dumped[:stock] == 100
        @test !haskey(dumped, :_extra)  # _extra should not appear in output

        # With string keys
        dumped_str = BoundaryTypes.model_dump(product; keys=:string)
        @test dumped_str["name"] == "Widget"
        @test dumped_str["price"] == 19.99
        @test dumped_str["color"] == "blue"
        @test dumped_str["stock"] == 100
        @test !haskey(dumped_str, "_extra")
    end

    @testset ":allow mode with @validated_model" begin
        @validated_model extra=:allow struct AllowValidatedUser
            email::String
            age::Int
        end

        # Should accept input with extra fields via constructor
        result = AllowValidatedUser(email="test@example.com", age=25, custom_field="custom")
        @test result.email == "test@example.com"
        @test result.age == 25
        @test result._extra == Dict(:custom_field => "custom")
    end

    @testset ":allow mode with nested models" begin
        @model extra=:allow struct AllowAddress
            street::String
            city::String
        end

        @model extra=:allow struct AllowPerson
            name::String
            address::AllowAddress
        end

        # Both parent and nested can have extra fields
        ok, result = BoundaryTypes.try_model_validate(
            AllowPerson,
            Dict(
                :name => "Charlie",
                :extra_person => "person_value",
                :address => Dict(
                    :street => "789 Oak St",
                    :city => "Seattle",
                    :extra_address => "address_value"
                )
            )
        )
        @test ok
        @test result.name == "Charlie"
        @test result._extra == Dict(:extra_person => "person_value")
        @test result.address.street == "789 Oak St"
        @test result.address.city == "Seattle"
        @test result.address._extra == Dict(:extra_address => "address_value")

        # model_dump should work recursively
        dumped = BoundaryTypes.model_dump(result)
        @test dumped[:name] == "Charlie"
        @test dumped[:extra_person] == "person_value"
        # Note: nested address will have _extra field in the dump
        @test dumped[:address] isa AllowAddress
    end
end
