using BoundaryTypes

@model struct TestStruct
    x::String
    y::String
end

# Custom rule defined outside
my_custom_rule() = BoundaryTypes.Rule(:custom, (v, ctx)->true, nothing)

try
    @rules TestStruct begin
        field(:x, my_custom_rule())
        field(:y, minlen(5)) # Standard rule, should work if exported
    end
    println("Rules defined successfully")
catch e
    println("Error defining rules: ", e)
    rethrow(e)
end
