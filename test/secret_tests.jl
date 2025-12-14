@testset "Secret field masking" begin
    @model Base.@kwdef struct SecretSignup
        email::String
        password::String
        age::Int = 0
    end

    @rules SecretSignup begin
        field(:email, regex(r"@"))
        field(:password, minlen(12), regex(r"[0-9]"), secret())
        field(:age, ge(0), le(150))
    end

    # password is marked as secret, so error values should be masked
    ok, err = try_model_validate(SecretSignup, Dict("email"=>"test@example.com", "password"=>"short"))
    @test !ok

    # Find password errors and verify they are masked
    password_errors = filter(e -> e.path == [:password], err.errors)
    @test !isempty(password_errors)
    @test all(e -> e.got == "***", password_errors)

    # Non-secret fields (email, age) should show actual values
    ok, err = try_model_validate(SecretSignup, Dict("email"=>"invalid", "password"=>"ValidPassword123", "age"=>-5))
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
    ok, err = try_model_validate(SecretSignup, Dict("email"=>"test@example.com", "password"=>"MySecret123"))
    @test !ok
    io = IOBuffer()
    showerror(io, err)
    output = String(take!(io))
    @test occursin("***", output)
    @test !occursin("MySecret123", output)  # actual password should not leak

    # Type error on secret field should also be masked
    ok, err = try_model_validate(SecretSignup, Dict("email"=>"test@example.com", "password"=>12345, "age"=>25))
    @test !ok
    password_type_errors = filter(e -> e.path == [:password] && e.code == :type, err.errors)
    @test !isempty(password_type_errors)
    @test all(e -> e.got == "***", password_type_errors)

    # Multiple password errors should all be masked
    ok, err = try_model_validate(SecretSignup, Dict("email"=>"test@example.com", "password"=>"short"))
    @test !ok
    password_all_errors = filter(e -> e.path == [:password], err.errors)
    @test length(password_all_errors) >= 2  # minlen and regex errors
    @test all(e -> e.got == "***", password_all_errors)

    # JSON parsing - secret field should be masked
    json_str = """{"email":"test@example.com", "password":"x"}"""
    ok, err = try_model_validate_json(SecretSignup, json_str)
    @test !ok
    password_json_errors = filter(e -> e.path == [:password], err.errors)
    @test !isempty(password_json_errors)
    @test all(e -> e.got == "***", password_json_errors)
end
