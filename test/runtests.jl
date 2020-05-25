using Test: @test, @testset

using BSON: load
using HTTP: HTTP

using HTTPPlayback: playback

@testset "HTTPPlayback.jl" begin
    mktempdir() do dir
        path = joinpath(dir, "test1.bson")
        @test playback(() -> 1, path) == 1
        @test isfile(path)
        @test load(path) == Dict(:responses => [])

        path = joinpath(dir, "test2.bson")
        @test !isfile(path)
        resp1 = playback(() -> HTTP.get("https://httpbin.org/get"), path)
        @test isfile(path)
        resp2 = playback(() -> HTTP.get("https://httpbin.org/get"), path)
        @test resp1.body == resp2.body
    end
end
