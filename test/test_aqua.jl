using Aqua: Aqua
using ITensorFormatter: ITensorFormatter
using Test: @testset

@testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(ITensorFormatter)
end
