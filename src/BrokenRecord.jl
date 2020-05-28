module BrokenRecord

export playback

using Core: kwftype

using BSON: bson, load
using Cassette: Cassette, overdub, prehook, @context
using HTTP: HTTP, Header, URI, header, mkheaders, nobody, request, request_uri
using Suppressor: @suppress

const FORMAT = v"1"
const DEFAULTS = Dict(
    :path => "",
    :ignore_headers => [],
    :ignore_query => [],
)

function __init__()
    # Hiding the stacktrace from Cassette#174.
    ctx = RecordingCtx(; metadata=(; responses=[]))
    @suppress try overdub(ctx, () -> HTTP.get("https://httpbin.org/get")) catch end
end

drop_keys(keys) = p -> !(p.first in keys)

"""
    configure!(; path=nothing, ignore_headers=nothing, ignore_query=nothing)

Set options globally so that you needn't pass keywords to every [`playback`](@ref) call.

## Keywords

- `path`: Path to the directory that contains data files.
  Any path you pass to [`playback`](@ref) will be relative to this path.
- `ignore_headers`: Names of headers to remove from requests.
- `ignore_query`: Names of query string parameters to remove from requests.
"""
function configure!(; path=nothing, ignore_headers=nothing, ignore_query=nothing)
    path === nothing || (DEFAULTS[:path] = path)
    ignore_headers === nothing || (DEFAULTS[:ignore_headers] = ignore_headers)
    ignore_query === nothing || (DEFAULTS[:ignore_query] = ignore_query)
    return nothing
end

"""
    playback(f, path; ignore_headers=[], ignore_query=[])

Run `f` while either recording to or playing back from the file at `path`.
See [`configure!`](@ref) for more information on the available keywords.
"""
function playback(
    f, path;
    ignore_headers=DEFAULTS[:ignore_headers], ignore_query=DEFAULTS[:ignore_query],
)
    metadata = (; responses=[], ignore_headers=ignore_headers, ignore_query=ignore_query)
    path = joinpath(DEFAULTS[:path], path)
    ctx = if isfile(path)
        data = load(path)
        PlaybackCtx(; metadata=(; metadata..., responses=data[:responses]))
    else
        RecordingCtx(; metadata=metadata)
    end

    result = overdub(ctx, f)
    after(ctx, path)
    return result
end

include("recording.jl")
include("playback.jl")

end
