module BrokenRecord

export playback

using Base.Threads: nthreads, threadid

using BSON: bson, load
using HTTP: HTTP, Header, Layer, Response, URI, body_was_streamed, header, insert_default!,
    mkheaders, nobody, remove_default!, request, request_uri, stack, top_layer

const FORMAT = v"1"
const DEFAULTS = Dict(
    :path => "",
    :ignore_headers => [],
    :ignore_query => [],
)
const STATE = map(1:nthreads()) do i
    (; responses=Response[], ignore_headers=String[], ignore_query=String[])
end

drop_keys(keys) = p -> !(p.first in keys)

get_state() = STATE[threadid()]

function reset_state()
    state = get_state()
    empty!(state.responses)
    empty!(state.ignore_headers)
    empty!(state.ignore_query)
end

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
    reset_state()
    state = get_state()
    append!(state.ignore_headers, ignore_headers)
    append!(state.ignore_query, ignore_query)

    path = joinpath(DEFAULTS[:path], path)
    before_layer, custom_layer = if isfile(path)
        top_layer(stack()), PlaybackLayer
    else
        Union{}, RecordingLayer
    end

    insert_default!(before_layer, custom_layer)
    before(custom_layer, path)
    result = try
        f()
    finally
        remove_default!(before_layer, custom_layer)
        after(custom_layer, path)
    end

    return result
end

include("recording.jl")
include("playback.jl")

end
