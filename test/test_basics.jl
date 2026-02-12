using ITensorFormatter: ITensorFormatter
using JuliaSyntax: SyntaxNode, parseall
using Test: @test, @testset

function organize(s)
    jst = parseall(SyntaxNode, s)
    return ITensorFormatter.organize_import_blocks(jst)
end

@testset "ITensorFormatter" begin
    @testset "no imports" begin
        @test organize("x = 1\n") == "x = 1\n"
    end

    @testset "single using with colon" begin
        @test organize("using Foo: bar\n") == "using Foo: bar\n"
    end

    @testset "single import with colon" begin
        @test organize("import Foo: bar\n") == "import Foo: bar\n"
    end

    @testset "bare using Package" begin
        @test organize("using Foo\n") == "using Foo\n"
    end

    @testset "bare import Package" begin
        @test organize("import Foo\n") == "import Foo\n"
    end

    @testset "sort symbols alphabetically" begin
        result = organize("using Foo: baz, bar\n")
        @test result == "using Foo: bar, baz\n"
    end

    @testset "self-reference stays first" begin
        result = organize("using Foo: bar, Foo\n")
        @test result == "using Foo: Foo, bar\n"
    end

    @testset "sort mixed symbols with self-reference" begin
        result = organize("using Foo: baz, Foo, Bar, bar\n")
        @test result == "using Foo: Foo, Bar, bar, baz\n"
    end

    @testset "merge duplicate using statements" begin
        result = organize("using Foo: bar\nusing Foo: baz\n")
        @test result == "using Foo: bar, baz\n"
    end

    @testset "merge duplicate import statements" begin
        result = organize("import Foo: bar\nimport Foo: baz\n")
        @test result == "import Foo: bar, baz\n"
    end

    @testset "import before using" begin
        result = organize("using Foo: foo\nimport Bar: bar\n")
        @test result == "import Bar: bar\nusing Foo: foo\n"
    end

    @testset "preserve code after imports" begin
        result = organize("using Foo: bar\nx = 1\n")
        @test result == "using Foo: bar\nx = 1\n"
    end

    @testset "preserve code before imports" begin
        result = organize("x = 1\nusing Foo: bar\n")
        @test result == "x = 1\nusing Foo: bar\n"
    end

    @testset "relative import using .Package" begin
        result = organize("using .Foo: bar\n")
        @test result == "using .Foo: bar\n"
    end

    @testset "relative import using ..Package" begin
        result = organize("using ..Foo: bar\n")
        @test result == "using ..Foo: bar\n"
    end

    @testset "bare relative using" begin
        result = organize("using .Foo\n")
        @test result == "using .Foo\n"
    end

    @testset "dotted module path" begin
        result = organize("using Foo.Bar: baz\n")
        @test result == "using Foo.Bar: baz\n"
    end

    @testset "import as" begin
        result = organize("import Foo as Bar\n")
        @test result == "import Foo as Bar\n"
    end

    @testset "import relative as" begin
        result = organize("import .Foo as Bar\n")
        @test result == "import .Foo as Bar\n"
    end

    @testset "bare using and using with colon" begin
        result = organize("using Foo\nusing Bar: baz\n")
        @test result == "using Bar: baz\nusing Foo\n"
    end

    @testset "only adjacent imports are collected" begin
        input = "using Foo: foo\nx = 1\nusing Bar: bar\n"
        result = organize(input)
        @test result == "using Foo: foo\nx = 1\nusing Bar: bar\n"
    end

    @testset "sort multiple using lines" begin
        result = organize("using Zebra: z\nusing Alpha: a\n")
        @test result == "using Alpha: a\nusing Zebra: z\n"
    end

    @testset "sort multiple import lines" begin
        result = organize("import Zebra: z\nimport Alpha: a\n")
        @test result == "import Alpha: a\nimport Zebra: z\n"
    end

    @testset "mixed bare and colon imports" begin
        result = organize("import Foo\nimport Bar: baz\n")
        @test result == "import Bar: baz\nimport Foo\n"
    end

    @testset "multiple separate import blocks" begin
        input = "using Baz: baz\nusing Foo: foo\nx = 1\nusing Zebra: z, a\nusing Alpha: a\n"
        result = organize(input)
        @test result ==
            "using Baz: baz\nusing Foo: foo\nx = 1\nusing Alpha: a\nusing Zebra: a, z\n"
    end
end
