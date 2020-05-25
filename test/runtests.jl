using Test: @test, @testset, @test_throws

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
        resp1 = playback(() -> HTTP.get("https://httpbin.org/get"), path)
        @test isfile(path)
        resp2 = playback(() -> HTTP.get("https://httpbin.org/get"), path)
        @test resp1.body == resp2.body

        path = joinpath(dir, "test3.bson")
        playback(() -> HTTP.get("https://httpbin.org/get"), path)
        @test_throws Exception playback(() -> HTTP.get("https://httpbin.org/ip"), path)
    end
end
