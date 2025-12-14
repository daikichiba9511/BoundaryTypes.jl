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
