using Documenter, DirectSearch

makedocs(;
    modules=[DirectSearch],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "Usage" => "man/usage.md",
            "Reporting" => "man/reporting.md",
            "Adding a Search Step" => "man/addsearch.md",
            "Adding a Poll Step" => "man/addpoll.md",
            "Constraints" => "man/constraints.md",
            "Cache" => "man/cache.md",
           ],
        "Reference" => [
            "Public API" => "ref/public.md",
            "Internal" => "ref/internal.md",
           ],
    ],
    repo="https://github.com/ImperialCollegeLondon/DirectSearch.jl/blob/{commit}{path}#L{line}",
    sitename="DirectSearch.jl",
    authors="EdwardStables <edward.stables1198@gmail.com>",
    assets=String[],
)

deploydocs(;
    repo="github.com/ImperialCollegeLondon/DirectSearch.jl",
)
