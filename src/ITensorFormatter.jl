module ITensorFormatter

if VERSION >= v"1.11.0-DEV.469"
    let str = "public main"
        eval(Meta.parse(str))
    end
end

using JuliaFormatter: JuliaFormatter
using JuliaSyntax: JuliaSyntax, @K_str, SyntaxNode, children, kind, parseall, span
using Runic: Runic

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
    import_to_using = true,
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

is_using_or_import(x) = kind(x) === K"using" || kind(x) === K"import"

function find_using_or_import(x)
    if is_using_or_import(x)
        return x.parent
    elseif iszero(length(children(x)))
        return nothing
    else
        for child in children(x)
            result = find_using_or_import(child)
            isnothing(result) || return result
        end
        return nothing
    end
end

char_range(x) = x.position:(x.position + span(x) - 1)

function organize_import_blocks_string(s)
    jst = parseall(SyntaxNode, s)
    return organize_import_blocks(jst)
end
organize_import_blocks_file(f) = organize_import_blocks_string(read(f, String))

# Sort symbols, but keep the module self-reference first if present
function sort_with_self_first(syms, self)
    self′ = pop!(syms, self, nothing)
    sorted = sort!(collect(syms))
    if self′ !== nothing
        pushfirst!(sorted, self)
    end
    return sorted
end

# Organize a single block of adjacent import/using statements
function organize_import_block(siblings, node_text)
    using_mods = Set{String}()
    using_syms = Dict{String, Set{String}}()
    import_mods = Set{String}()
    import_syms = Dict{String, Set{String}}()

    for s in siblings
        isusing = kind(s) === K"using"
        for a in children(s)
            if kind(a) === K":"
                a_args = children(a)
                mod = node_text(a_args[1])
                set = get!(Set, isusing ? using_syms : import_syms, mod)
                for i in 2:length(a_args)
                    push!(set, String(node_text(a_args[i])))
                end
            elseif kind(a) === K"." || kind(a) === K"importpath"
                push!(isusing ? using_mods : import_mods, String(node_text(a)))
            elseif !isusing && kind(a) === K"as"
                a_args = children(a)
                push!(import_mods, node_text(a_args[1]) * " as " * node_text(a_args[end]))
            else
                error("Unexpected syntax in using/import statement.")
            end
        end
    end

    import_lines = String[]
    for m in import_mods
        push!(import_lines, "import " * m)
    end
    for (m, s) in import_syms
        push!(import_lines, "import " * m * ": " * join(sort_with_self_first(s, m), ", "))
    end
    using_lines = String[]
    for m in using_mods
        push!(using_lines, "using " * m)
    end
    for (m, s) in using_syms
        push!(using_lines, "using " * m * ": " * join(sort_with_self_first(s, m), ", "))
    end
    io = IOBuffer()
    join(io, sort!(import_lines), "\n")
    length(import_lines) > 0 && length(using_lines) > 0 && print(io, "\n")
    join(io, sort!(using_lines), "\n")
    return String(take!(io))
end

function organize_import_blocks(input)
    src = JuliaSyntax.sourcetext(input)
    x = find_using_or_import(input)
    isnothing(x) && return src

    child_nodes = children(x)

    # Find all groups of adjacent import/using statements
    groups = Vector{Any}[]
    i = 1
    while i <= length(child_nodes)
        if is_using_or_import(child_nodes[i])
            group_start = i
            while i <= length(child_nodes) && is_using_or_import(child_nodes[i])
                i += 1
            end
            push!(groups, child_nodes[group_start:(i - 1)])
        else
            i += 1
        end
    end

    # Extract the source text of a node, trimming whitespace
    node_text(n) = strip(src[char_range(n)])

    # Process each group from right to left to preserve positions
    for siblings in reverse(groups)
        formatted = organize_import_block(siblings, node_text)
        first_pos = first(char_range(siblings[1]))
        last_pos = last(char_range(siblings[end]))
        src = src[1:(first_pos - 1)] * chomp(formatted) * src[(last_pos + 1):end]
    end

    return src
end

const ITENSORFORMATTER_VERSION = pkgversion(@__MODULE__)

# Print a typical cli program help message
function print_help()
    io = stdout
    printstyled(io, "NAME"; bold = true)
    println(io)
    println(io, "       ITensorFormatter.main - format Julia source code")
    println(io)
    printstyled(io, "SYNOPSIS"; bold = true)
    println(io)
    println(io, "       julia -m ITensorFormatter [<options>] <path>...")
    println(io)
    printstyled(io, "DESCRIPTION"; bold = true)
    println(io)
    println(
        io, """
               `ITensorFormatter.main` (typically invoked as `julia -m ITensorFormatter`)
               formats Julia source code using the ITensorFormatter.jl formatter.
        """,
    )
    printstyled(io, "OPTIONS"; bold = true)
    println(io)
    println(
        io, """
               <path>...
                   Input path(s) (files and/or directories) to process. For directories,
                   all files (recursively) with the '*.jl' suffix are used as input files.

               --help
                   Print this message.

               --version
                   Print ITensorFormatter and julia version information.
        """,
    )
    return
end

function print_version()
    print(stdout, "itfmt version ")
    print(stdout, ITENSORFORMATTER_VERSION)
    print(stdout, ", julia version ")
    print(stdout, VERSION)
    println(stdout)
    return
end

"""
    ITensorFormatter.main(argv)

Format Julia source files. Primarily formats using Runic formatting, but additionally
organizes using/import statements by merging adjacent blocks, sorting modules and symbols,
and line-wrapping. Accepts file paths and directories as arguments.

# Examples

```julia-repl
julia> using ITensorFormatter: ITensorFormatter

julia> ITensorFormatter.main(["."]);

julia> ITensorFormatter.main(["file1.jl", "file2.jl"]);

```
"""
function main(argv)
    argv_options = filter(startswith("--"), argv)
    if !isempty(argv_options)
        if "--help" in argv_options
            print_help()
            return 0
        elseif "--version" in argv_options
            print_version()
            return 0
        else
            return error("Options not supported: `$argv_options`.")
        end
    end
    # `argv` doesn't have any options, so treat all arguments as file/directory paths.
    isempty(argv) && return error("No input paths provided.")
    inputfiles = String[]
    for x in argv
        if isdir(x)
            Runic.scandir!(inputfiles, x)
        elseif isfile(x)
            push!(inputfiles, x) # Assume it is a file for now
        else
            error("Input path is not a file or directory: `$x`.")
        end
    end
    isempty(inputfiles) && return 0
    # Pass 1: Organize import/using blocks
    for inputfile in inputfiles
        content = organize_import_blocks_file(inputfile)
        write(inputfile, content)
    end
    # Pass 2: Formatting via JuliaFormatter
    JuliaFormatter.format(inputfiles; JULIAFORMATTER_OPTIONS...)
    # Pass 3: Re-organize imports (fix up any changes from JuliaFormatter, e.g. import_to_using)
    for inputfile in inputfiles
        content = organize_import_blocks_file(inputfile)
        write(inputfile, content)
    end
    # Pass 4: Format via JuliaFormatter again to fix import line wrapping
    JuliaFormatter.format(inputfiles; JULIAFORMATTER_OPTIONS...)
    # Pass 5: Canonicalize via Runic
    Runic.main(["--inplace"; inputfiles])
    return 0
end

@static if isdefined(Base, Symbol("@main"))
    @main
end

end
