@testset "BoundaryTypes JSON parsing" begin
    @model Base.@kwdef struct JsonSignup
        email::String
        password::String
        age::Int = 0
    end

    @rules JsonSignup begin
        field(:email, regex(r"@"))
        field(:password, minlen(12), regex(r"[0-9]"), secret())
        field(:age, ge(0), le(150))
    end

    # success with JSON string
    json_str = """{"email":"test@example.com", "password":"ValidPass123", "age":25}"""
    s = BoundaryTypes.model_validate_json(JsonSignup, json_str)
    @test s.email == "test@example.com"
    @test s.age == 25

    # JSON with default value (age missing)
    json_str2 = """{"email":"user@test.com", "password":"SecurePass456"}"""
    s2 = BoundaryTypes.model_validate_json(JsonSignup, json_str2)
    @test s2.age == 0

    # JSON validation error - email regex failure
    json_str3 = """{"email":"invalid", "password":"short"}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(JsonSignup, json_str3)

    # JSON validation error - missing required field
    json_str4 = """{"email":"test@example.com"}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(JsonSignup, json_str4)

    # JSON validation error - age out of range
    json_str5 = """{"email":"test@example.com", "password":"ValidPass123", "age":999}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(JsonSignup, json_str5)

    # JSON with extra field
    json_str6 = """{"email":"test@example.com", "password":"ValidPass123", "age":25, "unexpected":"field"}"""
    @test_throws BoundaryTypes.ValidationError BoundaryTypes.model_validate_json(JsonSignup, json_str6)
end
