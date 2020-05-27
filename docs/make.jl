using BrokenRecord
using Documenter

makedocs(;
    modules=[BrokenRecord],
    authors="Chris de Graaf <me@cdg.dev> and contributors",
    repo="https://github.com/christopher-dG/BrokenRecord.jl/blob/{commit}{path}#L{line}",
    sitename="BrokenRecord.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://docs.cdg.dev/BrokenRecord.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/christopher-dG/BrokenRecord.jl",
)
