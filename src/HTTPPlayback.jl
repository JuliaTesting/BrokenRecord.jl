module HTTPPlayback

using BSON: bson, load
using Cassette: Cassette, overdub, @context
using HTTP: HTTP, URI, header, request
using Suppressor: @suppress

function __init__()
    # Hiding the stacktrace from Cassette#174.
    ctx = RecordingCtx(; metadata=(; responses=[], save=identity))
    @suppress overdub(ctx, () -> HTTP.get("https://httpbin.org/get"))
end

@context RecordingCtx
Cassette.posthook(ctx::RecordingCtx, resp, ::typeof(request), ::Type{Union{}}, args...) =
    push!(ctx.metadata.responses, resp)
function after(ctx::RecordingCtx, path)
    mkpath(dirname(path))
    bson(path; responses=map(ctx.metadata.save, ctx.metadata.responses))
end

@context PlaybackCtx
function Cassette.prehook(
    ctx::PlaybackCtx,
    ::typeof(request),
    method::Union{AbstractString, Symbol},
    url, headers, body,
)
    isempty(ctx.metadata) && error("No responses remaining in the data file")
    response = ctx.metadata.load(ctx.metadata.responses[1])
    request = response.request
    method == request.method || error("Expected $(request.method) request, got $method")
    body == request.body || error("Request body does not match")
    issubset(headers, request.headers) || error("Request headers do not match")
    observed = URI(url)
    expected = URI("$(observed.scheme)://$(header(request, "Host"))$(request.target)")
    observed == expected || error("Expected request to $expected, got $observed")
end
function Cassette.overdub(
    ctx::PlaybackCtx,
    ::typeof(request),
    ::Union{AbstractString, Symbol},
    url, headers, body,
)
    return popfirst!(ctx.metadata.responses)
end

after(ctx::PlaybackCtx, path) = nothing

function playback(f, path; load_transform=identity, save_transform=identity)
    ctx = if isfile(path)
        data = load(path)
        metadata = (; responses=data[:responses], load=load_transform, save=save_transform)
        PlaybackCtx(; metadata=metadata)
    else
        RecordingCtx(; metadata=(responses=[], save=save_transform))
    end

    result = overdub(ctx, f)
    after(ctx, path)
    return result
end

end
