using Documenter, DirectSearch

makedocs(;
    modules=[DirectSearch],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Manual" => [
            "Usage" => "man/usage.md",
            "Stopping Conditions" => "man/addstoppingconditions.md",
            "Reporting" => "man/reporting.md",
            "Adding a Search Step" => "man/addsearch.md",
            "Adding a Poll Step" => "man/addpoll.md",
            "Cache" => "man/cache.md",
           ],
        "Reference" => [
            "Public API" => "ref/public.md",
            "Internal" => "ref/internal.md",
           ],
    ],
    repo="https://github.com/lb4418/DirectSearch.jl/blob/{commit}{path}#L{line}",
    sitename="DirectSearch.jl",
    authors="EdwardStables <edward.stables1198@gmail.com>, Lukas Baliunas <lb4418@imperial.ac.uk>",
    assets=String[],
)

deploydocs(;
    repo="https://github.com/lb4418/DirectSearch.jl",
)
