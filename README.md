# BrokenRecord

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliatesting.github.io/BrokenRecord.jl)
[![Build Status](https://travis-ci.com/JuliaTesting/BrokenRecord.jl.svg?branch=master)](https://travis-ci.com/JuliaTesting/BrokenRecord.jl)

A [VCR](https://github.com/vcr/vcr) clone in Julia.

> Record your test suite's HTTP interactions and replay them during future test runs for fast, deterministic, accurate tests.

```jl
julia> using BrokenRecord: configure!, playback

julia> using HTTP

julia> dir = mktempdir();

julia> configure!(; path=dir)

julia> isfile(joinpath(dir, "test.bson"))
false

julia> @time playback(() -> HTTP.get("https://httpbin.org/delay/5"), "test.bson");
  5.403699 seconds (51.95 k allocations: 2.944 MiB)

julia> isfile(joinpath(dir, "test.bson"))
true

julia> @time playback(() -> HTTP.get("https://httpbin.org/delay/5"), "test.bson");
  0.015231 seconds (35.24 k allocations: 1.831 MiB)
```
