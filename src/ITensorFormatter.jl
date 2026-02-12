module ITensorFormatter

using JuliaFormatter
using JuliaSyntax: @K_str, JuliaSyntax, SyntaxNode, children, kind, parseall, span
using Runic

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

char_range(x) = x.position:(x.position + span(x))

function organize_import_file(f)
    jst = parseall(SyntaxNode, read(f, String))
    return organize_import_block(jst)
end

function organize_import_block(input)
    # Collect all sibling blocks that are also using/import expressions

    x = find_using_or_import(input)
    isnothing(x) && return

    siblings = []

    child_nodes = children(x)
    ind = findfirst(is_using_or_import, child_nodes)

    while !isnothing(ind)
        push!(siblings, popat!(child_nodes, ind))
        ind = findfirst(is_using_or_import, child_nodes)
    end

    # Collect all modules and symbols
    using_mods = Set{String}()
    using_syms = Dict{String, Set{String}}()
    import_mods = Set{String}()
    import_syms = Dict{String, Set{String}}()

    # Joins e.g. [".", ".", "Foo", "Bar"] (from "using ..Foo.Bar") to "..Foo.Bar"
    function module_join(x)
        io = IOBuffer()
        for y in children(x)[1:(end - 1)]
            print(io, y.val)
            y.val == "." && continue
            print(io, ".")
        end
        print(io, children(x)[end].val)
        return String(take!(io))
    end

    for s in siblings
        isusing = kind(s) === K"using"
        for a in children(s)
            if kind(a) === K":"
                a_args = children(a)
                mod = module_join(a_args[1])
                set = get!(Set, isusing ? using_syms : import_syms, mod)
                for i in 2:length(a_args)
                    push!(set, join(y.val for y in children(a_args[i])))
                end
            elseif kind(a) === K"."
                push!(isusing ? using_mods : import_mods, module_join(a))
            else
                error("unreachable?")
            end
        end
    end

    # Rejoin and sort
    # TODO: Currently regular string sorting is used, which roughly will correspond to
    #       BlueStyle (modules, types, ..., functions) since usually CamelCase is used for
    #       modules, types, etc, but possibly this can be improved by using information
    #       available from SymbolServer
    import_lines = String[]
    for m in import_mods
        push!(import_lines, "import " * m)
    end
    for (m, s) in import_syms
        push!(import_lines, "import " * m * ": " * join(sort!(collect(s)), ", "))
    end
    using_lines = String[]
    for m in using_mods
        push!(using_lines, "using " * m)
    end
    for (m, s) in using_syms
        push!(using_lines, "using " * m * ": " * join(sort!(collect(s)), ", "))
    end
    io = IOBuffer()
    join(io, sort!(import_lines), "\n")
    length(import_lines) > 0 && print(io, "\n\n")
    join(io, sort!(using_lines), "\n")
    str_to_fmt = String(take!(io))

    # Line wrap the using/import statements only
    formatted = JuliaFormatter.format_text(str_to_fmt; join_lines_based_on_source = true)

    src = JuliaSyntax.sourcetext(input)

    statement_range = char_range(siblings[1])
    first_pos = first(char_range(siblings[1]))

    content = src[1:(first_pos - 1)] * formatted

    content_to_append = ""

    last_pos = last(char_range(siblings[1]))

    # Get the content between the using/import statements
    for s in siblings[2:end]
        statement_range = char_range(s)
        content_to_append *= src[(last_pos + 1):(first(statement_range) - 1)]
        last_pos = last(statement_range)
    end

    if length(content_to_append) > 1
        content_to_append = "\n" * content_to_append
    end

    # Tack this onto the end
    content *= content_to_append * src[(last_pos + 1):end]

    return content
end

function (@main)(ARGS)
    for file in ARGS
        _, ext = splitext(file)
        ext == ".jl" || error("Only .jl files are supported")
        content = organize_import_file(file)
        write(file, content)
    end
    Runic.main(ARGS)
    return 0
end

end
