using Test: @test, @testset, @test_throws

using BSON: load
using HTTP: HTTP

using HTTPPlayback: FORMAT, playback

@testset "HTTPPlayback.jl" begin
    mktempdir() do dir
        path = joinpath(dir, "test1.bson")
        @test playback(() -> 1, path) == 1
        @test isfile(path)
        @test load(path) == Dict(:responses => [], :format => FORMAT)

        path = joinpath(dir, "test2.bson")
        resp1 = playback(() -> HTTP.get("https://httpbin.org/get"), path)
        @test isfile(path)
        resp2 = playback(() -> HTTP.get("https://httpbin.org/get"), path)
        @test resp1.body == resp2.body

        path = joinpath(dir, "test3.bson")
        playback(path) do
            HTTP.post("https://httpbin.org/anything"; body="hi")
        end
        @test_throws Exception playback(path) do
            # Wrong body.
            HTTP.post("https://httpbin.org/anything"; body="there")
        end
        @test_throws Exception playback(path) do
            # Wrong method.
            HTTP.put("https://httpbin.org/anything"; body="hi")
        end
        @test_throws Exception playback(path) do
            # Wrong headers.
            HTTP.post("https://httpbin.org/post"; body="hi", headers=["foo" => "bar"])
        end
        @test_throws Exception playback(path) do
            # Wrong path.
            HTTP.post("https://httpbin.org/post"; body="hi")
        end
        @test_throws Exception playback(path) do
            # Wrong query.
            HTTP.post("https://httpbin.org/anything?foo=bar"; body="hi")
        end

        path = joinpath(dir, "test4.bson")
        resp1 = playback(() -> HTTP.get("https://httpbin.org/get"), path)
        resp2 = playback(path; ignore_headers=["foo"]) do
            HTTP.get("https://httpbin.org/get"; headers=["foo" => "bar"])
        end
        @test resp1.body == resp2.body
        resp3 = playback(path; ignore_query=["foo"]) do
            HTTP.get("https://httpbin.org/get"; query=Dict("foo" => "bar"))
        end
        @test resp1.body == resp3.body
    end
end
