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
