using HTTPPlayback
using Documenter

makedocs(;
    modules=[HTTPPlayback],
    authors="Chris de Graaf <me@cdg.dev> and contributors",
    repo="https://github.com/christopher-dG/HTTPPlayback.jl/blob/{commit}{path}#L{line}",
    sitename="HTTPPlayback.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://christopher-dG.github.io/HTTPPlayback.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/christopher-dG/HTTPPlayback.jl",
)
