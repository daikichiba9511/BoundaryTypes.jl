@testset "Direct API usage (without BoundaryTypes prefix)" begin
    @model Base.@kwdef struct ApiSignup
        email::String
        password::String
        age::Int = 0
    end

    @rules ApiSignup begin
        field(:email, regex(r"@"))
        field(:password, minlen(12), regex(r"[0-9]"), secret())
        field(:age, ge(0), le(150))
    end

    # model_validate - success
    s = model_validate(ApiSignup, Dict("email"=>"user@example.com", "password"=>"SecurePass123", "age"=>30))
    @test s.email == "user@example.com"
    @test s.password == "SecurePass123"
    @test s.age == 30

    # model_validate - with default value
    s2 = model_validate(ApiSignup, Dict("email"=>"test@test.com", "password"=>"ValidPass456"))
    @test s2.age == 0

    # model_validate - validation error
    @test_throws ValidationError model_validate(ApiSignup, Dict("email"=>"invalid", "password"=>"short"))

    # try_model_validate - success case
    ok, result = try_model_validate(ApiSignup, Dict("email"=>"good@email.com", "password"=>"LongPassword123", "age"=>25))
    @test ok
    @test result isa ApiSignup
    @test result.email == "good@email.com"

    # try_model_validate - failure case
    ok, err = try_model_validate(ApiSignup, Dict("email"=>"bademail", "password"=>"x"))
    @test !ok
    @test err isa ValidationError
    @test length(err.errors) >= 2

    # model_validate_json - success
    json_success = """{"email":"json@example.com", "password":"JsonPassword123", "age":40}"""
    s3 = model_validate_json(ApiSignup, json_success)
    @test s3.email == "json@example.com"
    @test s3.age == 40

    # model_validate_json - with default
    json_default = """{"email":"default@test.com", "password":"DefaultPass123"}"""
    s4 = model_validate_json(ApiSignup, json_default)
    @test s4.age == 0

    # model_validate_json - validation error
    json_invalid = """{"email":"noemail", "password":"short", "age":-10}"""
    @test_throws ValidationError model_validate_json(ApiSignup, json_invalid)

    # Using NamedTuple instead of Dict
    s5 = model_validate(ApiSignup, (email="named@tuple.com", password="NamedTuplePass123", age=50))
    @test s5.email == "named@tuple.com"
    @test s5.age == 50
end
