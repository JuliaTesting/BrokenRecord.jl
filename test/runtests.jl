using Test: @test, @testset, @test_throws

using BSON: load
using HTTP: HTTP

using BrokenRecord: FORMAT, configure!, playback

const url = "https://httpbin.org"

@testset "BrokenRecord.jl" begin
    mktempdir() do dir
        path = joinpath(dir, "test1.bson")
        @test playback(() -> 1, path) == 1
        @test isfile(path)
        @test load(path) == Dict(:responses => [], :format => FORMAT)

        path = joinpath(dir, "test2.bson")
        resp1 = playback(() -> HTTP.get("$url/get"), path)
        @test isfile(path)
        resp2 = playback(() -> HTTP.get("$url/get"), path)
        @test resp1.body == resp2.body

        path = joinpath(dir, "test3.bson")
        playback(() -> HTTP.post("$url/anything"; body="hi"), path)
        # Wrong body.
        @test_throws Exception playback(() -> HTTP.post("$url/anything"; body="bye"), path)
        # Wrong method.
        @test_throws Exception playback(() -> HTTP.put("$url/anything"; body="hi"), path)
        # Wrong headers.
        @test_throws Exception playback(path) do
            HTTP.post("$url/anything"; body="hi", headers=["foo" => "bar"])
        end
        # Wrong path.
        @test_throws Exception playback(() -> HTTP.post("$url/post"; body="hi"), path)
        # Wrong query.
        @test_throws Exception playback(path) do
            HTTP.post("$url/anything"; query=Dict("foo" => "bar"), body="hi")
        end

        path = joinpath(dir, "test4.bson")
        resp1 = playback(() -> HTTP.get("$url/get"), path)
        resp2 = playback(path; ignore_headers=["foo"]) do
            HTTP.get("$url/get"; headers=["foo" => "bar"])
        end
        @test resp1.body == resp2.body
        resp3 = playback(path; ignore_query=["foo"]) do
            HTTP.get("$url/get"; query=Dict("foo" => "bar"))
        end
        @test resp1.body == resp3.body

        path = joinpath(dir, "test5.bson")
        resp1 = playback(() -> HTTP.get("$url"), path)
        resp2 = playback(() -> HTTP.get("$url"), path)
        @test resp1.body == resp2.body

        path = joinpath(dir, "test6.bson")
        playback(path) do
            HTTP.get("$url/get")
            HTTP.post("$url/post")
        end
        @test_throws Exception playback(() -> HTTP.get("$url/get"), path)

        path = joinpath(dir, "test7.bson")
        playback(path) do
            resp = HTTP.get("$url/get")
            empty!(resp.body)
        end
        @test !isempty(playback(() -> HTTP.get("$url/get").body, path))
    end

    mktempdir() do dir
        configure!(; path=dir, ignore_headers=["foo"], ignore_query=["bar"])
        path = "test.bson"
        resp1 = playback(() -> HTTP.get("$url/get"), path)
        @test !isfile("test.bson")
        @test isfile(joinpath(dir, "test.bson"))
        resp2 = playback(path) do
            HTTP.get("$url/get"; headers=["foo" => "bar"], query=Dict("bar" => "baz"))
        end
        @test resp1.body == resp2.body
    end
end
