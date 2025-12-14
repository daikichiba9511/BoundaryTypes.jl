using Documenter
using BoundaryTypes

makedocs(
    sitename = "BoundaryTypes.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    modules = [BoundaryTypes],
    pages = [
        "Home" => "index.md",
        "API Reference" => "api.md",
    ],
    remotes = nothing,  # Disable remote source links for local development
    checkdocs = :none   # Don't check for missing docstrings
)
