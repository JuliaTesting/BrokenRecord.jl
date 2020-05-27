# HTTPPlayback

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://docs.cdg.dev/HTTPPlayback.jl/stable)
[![Build Status](https://travis-ci.com/christopher-dG/HTTPPlayback.jl.svg?branch=master)](https://travis-ci.com/christopher-dG/HTTPPlayback.jl)

A VCR clone in Julia.

> Record your test suite's HTTP interactions and replay them during future test runs for fast, deterministic, accurate tests.

```jl
julia> using HTTPPlayback: HTTP, playback

julia> isfile("test.bson")
false

julia> @time playback(() -> HTTP.get("https://httpbin.org/delay/5"), "test.bson");
  5.403699 seconds (51.95 k allocations: 2.944 MiB)

julia> isfile("test.bson")
true

julia> @time playback(() -> HTTP.get("https://httpbin.org/delay/5"), "test.bson");
  0.015231 seconds (35.24 k allocations: 1.831 MiB)
```
