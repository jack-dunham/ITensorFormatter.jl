# ITensorFormatter.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://itensor.github.io/ITensorFormatter.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://itensor.github.io/ITensorFormatter.jl/dev/)
[![Build Status](https://github.com/ITensor/ITensorFormatter.jl/actions/workflows/Tests.yml/badge.svg?branch=main)](https://github.com/ITensor/ITensorFormatter.jl/actions/workflows/Tests.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ITensor/ITensorFormatter.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ITensor/ITensorFormatter.jl)
[![Code Style](https://img.shields.io/badge/code_style-ITensor-purple)](https://github.com/ITensor/ITensorFormatter.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

ITensorFormatter.jl is a code formatter for Julia source files used by packages in the
ITensor ecosystem. It makes use of [Runic.jl](https://github.com/fredrikekre/Runic.jl),
and [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl), and also
organizes using/import statements by merging adjacent blocks, sorting modules and
symbols, and line-wrapping (similar to, and based off of, the using/import statement
organization functionality in
[LanguageServer.jl](https://github.com/julia-vscode/LanguageServer.jl)).

## Support

<picture>
  <source media="(prefers-color-scheme: dark)" width="20%" srcset="docs/src/assets/CCQ-dark.png">
  <img alt="Flatiron Center for Computational Quantum Physics logo." width="20%" src="docs/src/assets/CCQ.png">
</picture>


ITensorFormatter.jl is supported by the Flatiron Institute, a division of the Simons Foundation.

## Installation instructions

This package resides in the `ITensor/ITensorRegistry` local registry.
In order to install, simply add that registry through your package manager.
This step is only required once.
```julia
julia> using Pkg: Pkg

julia> Pkg.Registry.add(url = "https://github.com/ITensor/ITensorRegistry")
```
or:
```julia
julia> Pkg.Registry.add(url = "git@github.com:ITensor/ITensorRegistry.git")
```
if you want to use SSH credentials, which can make it so you don't have to enter your Github ursername and password when registering packages.

In Julia v1.12 and later, ITensorFormatter should be installed as a
[Pkg app](https://pkgdocs.julialang.org/dev/apps/):
```sh
julia -e 'using Pkg; Pkg.Apps.add("ITensorFormatter")'
```
Assuming `~/.julia/bin` is in your `PATH` you can now invoke `itfmt`, e.g.:
```sh
# Format all files in-place in the current directory (recursively)
# !! DON'T DO THIS FROM YOUR HOME DIRECTORY !!
itfmt .
```

### Legacy installation

In Julia v1.11 and earlier (or if you don't want to use a Pkg app), ITensorFormatter can
also be installed manually with Julia's package manager:
```sh
# Install ITensorFormatter
julia --project=@itfmt --startup-file=no -e 'using Pkg; Pkg.add("ITensorFormatter")'
# Install the itfmt shell script
curl -fsSL -o ~/.local/bin/itfmt https://raw.githubusercontent.com/ITensor/ITensorFormatter.jl/refs/heads/main/bin/itfmt
chmod +x ~/.local/bin/itfmt
```

---

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

