using Documenter, DirectSearch

makedocs(;
    modules=[DirectSearch],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/EdwardStables/DirectSearch.jl/blob/{commit}{path}#L{line}",
    sitename="DirectSearch.jl",
    authors="EdwardStables <edward.stables1198@gmail.com>",
    assets=String[],
)

deploydocs(;
    repo="github.com/EdwardStables/DirectSearch.jl",
)
