module HTTPPlayback

using BSON: bson, load
using Cassette: Cassette, disablehooks, overdub, @context
using HTTP: HTTP, request
using Suppressor: @suppress

function __init__()
    # Hiding the stacktrace from Cassette#174.
    ctx = RecordingCtx(; metadata=[])
    @suppress overdub(ctx, () -> HTTP.get("https://httpbin.org/get"))
end

@context RecordingCtx
Cassette.posthook(ctx::RecordingCtx, resp, ::typeof(request), ::Type{Union{}}, args...) =
    push!(ctx.metadata, resp)
function after(ctx::RecordingCtx, path)
    mkpath(dirname(path))
    bson(path; responses=ctx.metadata)
end

@context PlaybackCtx
Cassette.overdub(ctx::PlaybackCtx, ::typeof(request), args...) = popfirst!(ctx.metadata)
after(ctx::PlaybackCtx, path) = nothing

function playback(f, path; transform=identity)
    ctx = if isfile(path)
        data = load(path)
        disablehooks(PlaybackCtx(; metadata=data[:responses]))
    else
        RecordingCtx(; metadata=[])
    end

    result = overdub(ctx, f)
    after(ctx, path)
    return result
end

end
