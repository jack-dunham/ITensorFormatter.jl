using Documenter: Documenter, DocMeta, deploydocs, makedocs
using ITensorFormatter: ITensorFormatter

DocMeta.setdocmeta!(
    ITensorFormatter, :DocTestSetup, :(using ITensorFormatter); recursive = true
)

include("make_index.jl")

makedocs(;
    modules = [ITensorFormatter],
    authors = "ITensor developers <support@itensor.org> and contributors",
    sitename = "ITensorFormatter.jl",
    format = Documenter.HTML(;
        canonical = "https://itensor.github.io/ITensorFormatter.jl",
        edit_link = "main",
        assets = ["assets/favicon.ico", "assets/extras.css"]
    ),
    pages = ["Home" => "index.md", "Reference" => "reference.md"]
)

deploydocs(;
    repo = "github.com/ITensor/ITensorFormatter.jl", devbranch = "main", push_preview = true
)
