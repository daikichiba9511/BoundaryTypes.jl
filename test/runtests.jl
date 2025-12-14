using Test
using BoundaryTypes

@testset "BoundaryTypes.jl" begin
    include("basic_tests.jl")
    include("validation_tests.jl")
    include("json_tests.jl")
    include("secret_tests.jl")
    include("api_tests.jl")
    include("constructor_tests.jl")
    include("update_tests.jl")
    include("introspection_tests.jl")
    include("nested_tests.jl")
    include("extra_field_tests.jl")
    include("collection_tests.jl")
    include("advanced_rules_tests.jl")
end
