module ITensorFormatter

if VERSION >= v"1.11.0-DEV.469"
    let str = "public main"
        eval(Meta.parse(str))
    end
end

using JuliaFormatter: JuliaFormatter
using JuliaSyntax: JuliaSyntax, @K_str, SyntaxNode, children, kind, parseall, span
using Runic: Runic

function is_using_or_import(x)
    return kind(x) === K"using" || kind(x) === K"import"
end

function find_using_or_import(x)
    if is_using_or_import(x)
        return x.parent
    elseif iszero(length(children(x)))
        return nothing
    else
        for child in children(x)
            x = find_using_or_import(child)
            isnothing(x) || return x
        end
        return nothing
    end
end

char_range(x) = x.position:(x.position + span(x) - 1)

function organize_import_file(f)
    jst = parseall(SyntaxNode, read(f, String))
    return organize_import_block(jst)
end

function organize_import_block(input)
    # Collect all sibling blocks that are also using/import expressions

    x = find_using_or_import(input)
    isnothing(x) && return JuliaSyntax.sourcetext(input)

    siblings = []

    child_nodes = children(x)
    first_ind = findfirst(is_using_or_import, child_nodes)

    for ind in first_ind:length(child_nodes)
        if is_using_or_import(child_nodes[ind])
            push!(siblings, child_nodes[ind])
        else
            break
        end
    end

    src = JuliaSyntax.sourcetext(input)

    # Collect all modules and symbols
    using_mods = Set{String}()
    using_syms = Dict{String, Set{String}}()
    import_mods = Set{String}()
    import_syms = Dict{String, Set{String}}()

    # Extract the source text of a node, trimming whitespace
    node_text(x) = strip(src[char_range(x)])

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

    # Rejoin and sort
    # TODO: Currently regular string sorting is used, which roughly will correspond to
    #       BlueStyle (modules, types, ..., functions) since usually CamelCase is used for
    #       modules, types, etc, but possibly this can be improved by using information
    #       available from SymbolServer
    # Sort symbols, but keep the module self-reference first if present
    function sort_with_self_first(syms, self)
        self′ = pop!(syms, self, nothing)
        sorted = sort!(collect(syms))
        if self′ !== nothing
            pushfirst!(sorted, self)
        end
        return sorted
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
    str_to_fmt = String(take!(io))

    # Line wrap the using/import statements only
    formatted = JuliaFormatter.format_text(str_to_fmt; join_lines_based_on_source = true)

    first_pos = first(char_range(siblings[1]))
    last_pos = last(char_range(siblings[end]))

    content = src[1:(first_pos - 1)] * chomp(formatted) * src[(last_pos + 1):end]

    return content
end

"""
    ITensorFormatter.main(argv)

Format Julia source files. Primarily formats using Runic formatting, but additionally
organizes using/import statements by merging adjacent blocks, sorting modules and symbols,
and line-wrapping. Accepts file paths and directories as arguments. Options starting with
`--` are forwarded to Runic, see the
[Runic documentation](https://github.com/fredrikekre/Runic.jl) for more details.
"""
function main(argv)
    inputfiles = String[]
    x = filter(!startswith("--"), argv)
    for x in argv
        if startswith(x, "--")
            # Ignore options for now, they are assumed to be for Runic.
        elseif isdir(x)
            Runic.scandir!(inputfiles, x)
        else # isfile(x)
            push!(inputfiles, x) # Assume it is a file for now
        end
    end
    for inputfile in inputfiles
        content = organize_import_file(inputfile)
        write(inputfile, content)
    end
    Runic.main(argv)
    return 0
end

@static if isdefined(Base, Symbol("@main"))
    @main
end

end
