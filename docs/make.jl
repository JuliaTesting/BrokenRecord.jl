using BrokenRecord
using Documenter

makedocs(;
    modules=[BrokenRecord],
    authors="Chris de Graaf <me@cdg.dev> and contributors",
    repo="https://github.com/JuliaTesting/BrokenRecord.jl/blob/{commit}{path}#L{line}",
    sitename="BrokenRecord.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://juliatesting.github.io/BrokenRecord.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaTesting/BrokenRecord.jl",
)
