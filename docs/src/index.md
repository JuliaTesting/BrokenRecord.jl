# Overview of BrokenRecord.jl

> BrokenRecord.jl helps make your tests deterministic and independent of external services by recording and replaying HTTP interactions.
> With BrokenRecord.jl, you can test code that makes HTTP requests without relying on upstream services or network availability. 
> It is directly inspired by the package, [VCR](https://github.com/vcr/vcr).

It operates in two modes via the `playback` entrypoint:

- **Recording mode**: When a reference file does not exist, BrokenRecord.jl enters recording mode. 
In this mode, all outgoing HTTP requests from your code are made as usual. 
The full details of each request and its corresponding response are captured and saved to a reference file. 
Typically, you generate these reference files on your development machine and check it into your Git repository.

- **Playback mode**: If the reference file already exists, BrokenRecord.jl switches to playback mode. 
During test execution, instead of making real HTTP requests, the package reads the next recorded request/response pair from associated reference files. 
If the request matches what request the code is making, the saved response is returned. 
This eliminates the need for a live internet connection and ensures consistent, reproducible test results—ideal for continuous integration environments.

# Workflow with BrokenRecord.jl

In practice, here is how you should consider using BrokenRecord.jl:

1. Write your test as usual, using real HTTP requests in the function you're testing.
2. Wrap your test code in the `playback` function, passing a path to a reference file (such as a `.bson` file).
3. On the first run, if the reference file doesn’t exist, BrokenRecord.jl enters recording mode:
   - It performs the actual HTTP requests.
   - It saves the request and response details to the reference file.
4. On subsequent runs (e.g., such as in CI), BrokenRecord.jl enters playback mode:
   - It intercepts HTTP requests and returns the previously recorded responses from the reference file.
   - It verifies that the current request matches the recorded one before replaying the response.
5. You write your own `@test` assertions inside the `playback` block to validate the behavior of your code.

## Example Workflow

Here's an example workflow that describes in general how the package API works:

```julia
using BrokenRecord: configure!, playback
using HTTP

# Create a temporary directory to store the reference file
dir = "test/fixtures"

# Tell BrokenRecord.jl to store reference files in this directory
configure!(; path=dir)

# Check whether the reference file already exists (it doesn't yet)
isfile(joinpath(dir, "test.bson")) 

#= 

This is the first run: the HTTP request is actually made 
The request and response are recorded to "test.bson"

=#
playback(() -> HTTP.get("https://httpbin.org/delay/5"), "test.bson")

# Now the reference file has been created
isfile(joinpath(dir, "test.bson"))

#=

This is the second run: the HTTP request is intercepted and replayed from the reference file
No actual network call is made

=#
playback(() -> HTTP.get("https://httpbin.org/delay/5"), "test.bson")
```

## Example in Testing Environment

Here is an example of how you might use BrokenRecord.jl within your testing suite (notice how you can use BrokenRecord.jl within block syntax as well):

```julia
#= 

Example taken from 
https://github.com/SebastianM-C/RegistryCI.jl

=#
using BrokenRecord: BrokenRecord, HTTP, playback
using RegistryCI: TagBot
using Test: @test, @testset

const TB = TagBot

@testset "notify" begin
    playback("notify.bson") do
        comment = TB.notify("christopher-dG/TestRepo", 4, "test notification")
        @test comment.body == "test notification"
    end
end
```

# Frequently Asked Questions

> Where should I put my reference files?

We suggest putting them in the `test` directory in a sub-directory called `fixtures` (i.e. `test/fixtures/reference_1.bson`).

> Suppose I have more complicated HTTP requests like a POST that contains a payload of some kind. Is BrokenRecord.jl robust enough to handle those sorts of requests?  

Yes, that should be fine.

> If I have a request that is supposed to download a file, how should I use BrokenRecord.jl to test for that?

You may potentially encounter the [streaming issue](https://github.com/JuliaTesting/BrokenRecord.jl/issues/22), but HTTP doesn’t have any actual file downloading methods, so extra code for writing to the file would not be touched by BrokenRecord.jl.

> What is a test fixture?

This [wikipedia entry on Test Fixtures](https://en.wikipedia.org/wiki/Test_fixture#Software) gives an excellent overview! 

# API

```@meta
CurrentModule = BrokenRecord
```

# BrokenRecord

```@index
```

```@autodocs
Modules = [BrokenRecord]
```
