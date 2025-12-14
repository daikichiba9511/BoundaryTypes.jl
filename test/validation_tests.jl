@testset "BoundaryTypes validation errors" begin
    @model Base.@kwdef struct ValidationSignup
        email::String
        password::String
        age::Int = 0
    end

    @rules ValidationSignup begin
        field(:email, regex(r"@"))
        field(:password, minlen(12), regex(r"[0-9]"), secret())
        field(:age, ge(0), le(150))
    end

    # missing required field (email)
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate(
        ValidationSignup,
        Dict("password"=>"ValidPass123", "age"=>25)
    )

    # missing required field (password)
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate(
        ValidationSignup,
        Dict("email"=>"test@example.com", "age"=>25)
    )

    # email regex validation failure (no @)
    ok, err = BoundaryTypes.try_model_validate(
        ValidationSignup,
        Dict("email"=>"invalidemail", "password"=>"ValidPass123")
    )
    @test !ok
    @test any(e.code == :regex && e.path == [:email] for e in err.errors)

    # password too short (minlen)
    ok, err = BoundaryTypes.try_model_validate(
        ValidationSignup,
        Dict("email"=>"test@example.com", "password"=>"Short1")
    )
    @test !ok
    @test any(e.code == :minlen && e.path == [:password] for e in err.errors)

    # password missing number (regex)
    ok, err = BoundaryTypes.try_model_validate(
        ValidationSignup,
        Dict("email"=>"test@example.com", "password"=>"NoNumberPassword")
    )
    @test !ok
    @test any(e.code == :regex && e.path == [:password] for e in err.errors)

    # age too low (ge)
    ok, err = BoundaryTypes.try_model_validate(
        ValidationSignup,
        Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>-1)
    )
    @test !ok
    @test any(e.code == :ge && e.path == [:age] for e in err.errors)

    # age too high (le)
    ok, err = BoundaryTypes.try_model_validate(
        ValidationSignup,
        Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>200)
    )
    @test !ok
    @test any(e.code == :le && e.path == [:age] for e in err.errors)

    # extra field forbidden
    ok, err = BoundaryTypes.try_model_validate(
        ValidationSignup,
        Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>25, "extra_field"=>"not allowed")
    )
    @test !ok
    @test any(e.code == :extra && e.path == [:extra_field] for e in err.errors)

    # multiple validation errors at once
    ok, err = BoundaryTypes.try_model_validate(
        ValidationSignup,
        Dict("email"=>"noemail", "password"=>"short", "age"=>-5)
    )
    @test !ok
    @test length(err.errors) >= 3
    @test any(e.code == :regex && e.path == [:email] for e in err.errors)
    @test any(e.code == :minlen && e.path == [:password] for e in err.errors)
    @test any(e.code == :ge && e.path == [:age] for e in err.errors)
end

@testset "Type mismatch errors" begin
    @model Base.@kwdef struct TypeMismatchSignup
        email::String
        password::String
        age::Int = 0
    end

    @rules TypeMismatchSignup begin
        field(:email, regex(r"@"))
        field(:password, minlen(12), regex(r"[0-9]"), secret())
        field(:age, ge(0), le(150))
    end

    # email should be String, not Int
    ok, err = try_model_validate(TypeMismatchSignup, Dict("email"=>12345, "password"=>"ValidPass123", "age"=>25))
    @test !ok
    @test any(e.code == :type && e.path == [:email] for e in err.errors)
    @test any(e -> e.code == :type && occursin("expected String", e.message), err.errors)

    # password should be String, not Int
    ok, err = try_model_validate(TypeMismatchSignup, Dict("email"=>"test@example.com", "password"=>999, "age"=>25))
    @test !ok
    @test any(e.code == :type && e.path == [:password] for e in err.errors)

    # age should be Int, not String
    ok, err = try_model_validate(TypeMismatchSignup, Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>"not a number"))
    @test !ok
    @test any(e.code == :type && e.path == [:age] for e in err.errors)
    @test any(e -> e.code == :type && occursin("expected Int", e.message), err.errors)

    # age should be Int, not Float
    ok, err = try_model_validate(TypeMismatchSignup, Dict("email"=>"test@example.com", "password"=>"ValidPass123", "age"=>25.5))
    @test !ok
    @test any(e.code == :type && e.path == [:age] for e in err.errors)

    # multiple type errors
    ok, err = try_model_validate(TypeMismatchSignup, Dict("email"=>123, "password"=>456, "age"=>"string"))
    @test !ok
    @test length(err.errors) >= 3
    @test count(e -> e.code == :type, err.errors) >= 3

    # JSON with type mismatch - age as string
    json_type_err = """{"email":"test@example.com", "password":"ValidPass123", "age":"twenty"}"""
    ok, err = try_model_validate_json(TypeMismatchSignup, json_type_err)
    @test !ok
    @test any(e.code == :type && e.path == [:age] for e in err.errors)

    # JSON with type mismatch - email as number
    json_type_err2 = """{"email":12345, "password":"ValidPass123", "age":25}"""
    ok, err = try_model_validate_json(TypeMismatchSignup, json_type_err2)
    @test !ok
    @test any(e.code == :type && e.path == [:email] for e in err.errors)

    # Test that type error is thrown (not just collected)
    @test_throws ValidationError model_validate(TypeMismatchSignup, Dict("email"=>12345, "password"=>"ValidPass123"))
end
