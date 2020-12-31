module BrokenRecord

export playback

using Base.Threads: nthreads, threadid

using BSON: BSON
using HTTP: HTTP, Header, Layer, Response, URI, body_was_streamed, header, insert_default!,
    mkheaders, nobody, remove_default!, request, request_uri, stack, top_layer
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

mutable struct Context
    recording::Bool
    responses::Vector{Response}
    ignore_headers::Vector{String}
    ignore_query::Vector{String}
    meta::Dict{Symbol, Any}
    storage::Type

    Context() = new(false, [], [], [], Dict())
end

Base.getproperty(ctx::Context, k::Symbol) = get(getfield(ctx, :meta), k, nothing)
Base.setproperty!(ctx::Context, k::Symbol, v) = getfield(ctx, :meta)[k] = v

const CONTEXTS = map(_ -> Context(), 1:nthreads())

drop_keys(keys) = p -> !(p.first in keys)

get_ctx() = CONTEXTS[threadid()]

function reset_context()
    ctx = get_context()
    empty!(getfield(ctx, :responses))
    empty!(getfield(ctx, :ignore_headers))
    empty!(getfield(ctx, :ignore_query))
    empty!(getfield(ctx, :meta))
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
    reset_context()
    ctx = get_context()
    append!(getfield(ctx, :ignore_headers), ignore_headers)
    append!(getfield(ctx, :ignore_query), ignore_query)

    path = joinpath(DEFAULTS[:path], replace(path, isspace => "_"))
    storage, path = get_storage(path, DEFAULTS[:extension])
    setfield!(ctx, :storage, storage)
    before_layer, custom_layer = if isfile(path)
        top_layer(stack()), PlaybackLayer
    else
        Union{}, RecordingLayer
    end

    before(custom_layer, ctx, path)
    insert_default!(before_layer, custom_layer)
    return try
        f(ctx)
    finally
        remove_default!(before_layer, custom_layer)
        after(custom_layer, ctx, path)
    end
end

include("recording.jl")
include("playback.jl")
include("storage.jl")

end
