module BrokenRecord

export playback

using Base.Threads: nthreads, threadid

using BSON: BSON
using HTTP: HTTP, Header, Response, URI, header, mkheaders
using JLD2: JLD2
using JLSO: JLSO
using JSON: JSON
using YAML: YAML

const FORMAT = v"1"
const DEFAULTS = Dict(
    :path => "",
    :ignore_headers => [],
    :ignore_query => [],
    :extension => "yml",
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
    configure!(;
        path=nothing,
        extension=nothing,
        ignore_headers=nothing,
        ignore_query=nothing,
    )

Set options globally so that you needn't pass keywords to every [`playback`](@ref) call.

## Keywords

- `path`: Path to the directory that contains data files.
  Any path you pass to [`playback`](@ref) will be relative to this path.
- `extension`: File extension for data files, which determines the storage backend used.
  The default is `"yml"`, which produces YAML files.
- `ignore_headers`: Names of headers to remove from requests.
- `ignore_query`: Names of query string parameters to remove from requests.
"""
function configure!(; path=nothing, extension=nothing, ignore_headers=nothing, ignore_query=nothing)
    path === nothing || (DEFAULTS[:path] = path)
    extension === nothing || (DEFAULTS[:extension] = extension)
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

    path = joinpath(DEFAULTS[:path], replace(path, isspace => "_"))
    storage, path = get_storage(path, DEFAULTS[:extension])

    T, layer = isfile(path) ? (PlaybackLayer, playbacklayer) : (RecordingLayer, recordinglayer)

    before(T, storage, path)
    HTTP.pushlayer!(layer)
    return try
        f()
    finally
        HTTP.poplayer!()
        after(T, storage, path)
    end
end

include("recording.jl")
include("playback.jl")
include("storage.jl")

end
