using JuliaFormatter: JuliaFormatter
using Runic: Runic

isjlfile(path) = endswith(last(splitpath(path)), ".jl")

# JuliaFormatter options chosen to be compatible with Runic.
# JuliaFormatter handles line wrapping (which Runic doesn't do),
# then Runic runs last to canonicalize everything else.
const JULIAFORMATTER_OPTIONS = (
    style = JuliaFormatter.DefaultStyle(),
    indent = 4,
    margin = 92,
    always_for_in = true,
    for_in_replacement = "in",
    # Semantic transformations consistent with Runic
    always_use_return = true,
    # Ideally we would use `import_to_using = true`, however that changes the import
    # formatting, which requires reformatting imports again which is expensive without
    # a better solution besides running JuliaFormatter twice.
    import_to_using = false,
    pipe_to_function_call = true,
    short_to_long_function_def = true,
    long_to_short_function_def = false,
    conditional_to_if = true,
    short_circuit_to_if = false,
    # Whitespace options consistent with Runic
    whitespace_typedefs = true,
    whitespace_ops_in_indices = true,
    whitespace_in_kwargs = true,
    # Annotation/structural changes
    annotate_untyped_fields_with_any = true,
    format_docstrings = true,
    remove_extra_newlines = true,
    indent_submodule = true,
    separate_kwargs_with_semicolon = true,
    surround_whereop_typeparameters = true,
    disallow_single_arg_nesting = false,
    normalize_line_endings = "unix",
    # Line-wrapping-related options
    trailing_comma = false,
    join_lines_based_on_source = true,
    # Floating point formatting options
    trailing_zero = true,
)
function format_juliaformatter!(paths)
    JuliaFormatter.format(paths; JULIAFORMATTER_OPTIONS...)
    return nothing
end

function format_runic!(paths::AbstractVector{<:AbstractString})
    Runic.main(["--inplace"; paths])
    return nothing
end
format_runic!(path::AbstractString) = format_runic!([path])

const ITENSORFORMATTER_VERSION = pkgversion(@__MODULE__)

# Print a typical cli program help message
function print_help(io::IO = stdout)
    printstyled(io, "NAME"; bold = true)
    println(io)
    println(io, "       ITensorFormatter.main - format Julia source code")
    println(
        io,
        "       ITensorPkgFormatter.main - format ITensor Julia packages and generate READMEs"
    )
    println(io)
    printstyled(io, "SYNOPSIS"; bold = true)
    println(io)
    println(io, "       julia -m ITensorFormatter [<options>] <path>...")
    println(io, "       julia -m ITensorPkgFormatter [<options>] <path>...")
    println(io)
    printstyled(io, "DESCRIPTION"; bold = true)
    println(io)
    println(
        io,
        """
        `ITensorFormatter.main` (typically invoked as `julia -m ITensorFormatter` or `itfmt`)
        formats Julia source code, Project.toml, and optionally YAML files using the ITensorFormatter.jl formatter.
        """
    )
    println(
        io,
        """
        `ITensorPkgFormatter.main` (typically invoked as `julia -m ITensorPkgFormatter` or `itpkgfmt`)
        performs all formatting as above, and additionally generates README documentation for each provided ITensor package directory.
        """
    )
    printstyled(io, "OPTIONS"; bold = true)
    println(io)
    println(
        io,
        """
        <path>...\n\
        Input path(s) (files and/or directories) to process. For directories,\n\
        all files (recursively) with the '*.jl' suffix are used as input files.\n\
        --help\n\
        Print this message.\n\
        --version\n\
        Print ITensorFormatter and julia version information.\n\
        --yaml\n\
        Also format YAML files (*.yml, *.yaml). Disabled by default.\n        """
    )
    return nothing
end

# One shared generator for the plain-text help
function help_text()
    # ensure no ANSI styling sneaks into docstring text
    return sprint(io -> print_help(IOContext(io, :color => false)))
end

# Docstring-friendly wrapper
help_markdown() = "```text\n" * help_text() * "\n```"

function print_version()
    print(stdout, "itfmt version ")
    print(stdout, ITENSORFORMATTER_VERSION)
    print(stdout, ", julia version ")
    print(stdout, VERSION)
    println(stdout)
    return
end

function process_args(argv)
    format = true
    format_yaml = false
    argv_options = filter(startswith("--"), argv)

    if "--help" in argv_options
        print_help()
        return (; paths = String[], format = false, format_yaml = false)
    elseif "--version" in argv_options
        print_version()
        return (; paths = String[], format = false, format_yaml = false)
    end

    format_yaml = "--yaml" ∈ argv_options
    unknown = setdiff(argv_options, ["--yaml"])
    !isempty(unknown) && error("Options not supported: `$unknown`.")

    paths = filter(x -> !startswith(x, "--"), argv)
    return (; paths, format, format_yaml)
end

function format_stdin()
    content = read(stdin, String)
    content = organize_import_blocks_string(content)
    content = JuliaFormatter.format_text(content; JULIAFORMATTER_OPTIONS...)
    content = Runic.format_string(content)
    write(stdout, content)
    return 0
end

"""
$(help_markdown())
"""
function main(argv)
    (; paths, format, format_yaml) = process_args(argv)
    !format && return 0
    if isempty(paths)
        format_stdin()
        return 0
    end
    jlfiles = filterpaths(isjlfile, paths)
    yamlfiles = format_yaml ? filterpaths(isyamlfile, paths) : String[]
    projectomls = filterpaths(isprojecttoml, paths)
    # Pass 1: Organize import/using blocks
    format_imports!(jlfiles)
    # Pass 2: Format via JuliaFormatter
    format_juliaformatter!(jlfiles)
    # Pass 3: Canonicalize via Runic
    format_runic!(jlfiles)
    # Pass 4: Format Project.toml files
    format_project_tomls!(projectomls)
    # Pass 5: Format YAML files (optional)
    format_yaml && format_yamls!(yamlfiles)
    return 0
end

@static if isdefined(Base, Symbol("@main"))
    @main
end
