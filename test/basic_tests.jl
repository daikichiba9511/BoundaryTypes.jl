@testset "BoundaryTypes basic" begin
    @model Base.@kwdef struct BasicSignup
        email::String
        password::String
        age::Int = 0
    end

    @rules BasicSignup begin
        field(:email, regex(r"@"))
        field(:password, minlen(12), regex(r"[0-9]"), secret())
        field(:age, ge(0), le(150))
    end

    # success
    s = BoundaryTypes.model_validate(BasicSignup, Dict("email"=>"a@b", "password"=>"A23456789012", "age"=>10))
    @test s.age == 10

    # default validated
    s2 = BoundaryTypes.model_validate(BasicSignup, Dict("email"=>"a@b", "password"=>"A23456789012"))
    @test s2.age == 0

    # aggregated errors
    ok, err = BoundaryTypes.try_model_validate(BasicSignup, Dict("email"=>"ab", "password"=>"short"))
    @test !ok
    @test err isa BoundaryTypes.ValidationError
    @test length(err.errors) >= 2
    @test any(e.code == :regex && e.path == [:email] for e in err.errors)

    # secret masks got in showerror (smoke)
    io = IOBuffer()
    showerror(io, err)
    @test occursin("***", String(take!(io)))
end
