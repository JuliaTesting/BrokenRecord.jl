module HTTPPlayback

export playback

using Core: kwftype

using BSON: bson, load
using Cassette: Cassette, overdub, prehook, @context
using HTTP: HTTP, Header, URI, header, mkheaders, nobody, request, request_uri
using Suppressor: @suppress

const FORMAT = v"1"

function __init__()
    # Hiding the stacktrace from Cassette#174.
    ctx = RecordingCtx(; metadata=(; responses=[]))
    @suppress try overdub(ctx, () -> HTTP.get("https://httpbin.org/get")) catch end
end

const HTTPMethod = Union{AbstractString, Symbol}
const NoQuery = Dict{SubString{String}, SubString{String}}

parse_query(uri) = isempty(uri.query) ? NoQuery() : Dict(split.(split(uri.query, '&'), '='))

drop_keys(keys) = p -> !(p.first in keys)

function filter_query(request, ignore)
    uri = URI(request.target)
    query = filter(drop_keys(ignore), parse_query(uri))
    return if isempty(query)
        uri.path
    else
        uri.path * '?' * join((join(p, '=') for p in query), '&')
    end
end

check_body(request, body) = request.body == body || error("Request body does not match")

check_method(request, method) =
    request.method == method || error("Expected $(request.method) request, got $method")

function check_headers(request, headers; ignore)
    observed = filter(drop_keys(ignore), headers)
    issubset(observed, request.headers) || error("Request headers do not match")
end

function check_uri(request, uri; ignore)
    # Check host.
    host = header(request, "Host")
    host == uri.host || error("Expected request to $host, got $(uri.host)")
    # Check path.
    expected = HTTP.URI(request.target)
    expected.path == uri.path ||
        error("Expected request to $(expected.path), got $(uri.path)")
    # Check query string parameters.
    expected_q = @show parse_query(expected)
    observed_q = @show filter(drop_keys(ignore), parse_query(uri))
    expected_q == observed_q || error("Query string parameters do not match")
end

@context RecordingCtx
Cassette.posthook(ctx::RecordingCtx, resp, ::typeof(request), ::Type{Union{}}, args...) =
    push!(ctx.metadata.responses, resp)
function after(ctx::RecordingCtx, path)
    for resp in ctx.metadata.responses
        filter!(drop_keys(ctx.metadata.ignore_headers), resp.headers)
        resp.request.target = filter_query(resp.request, ctx.metadata.ignore_query)
    end
    mkpath(dirname(path))
    bson(path; responses=ctx.metadata.responses, format=FORMAT)
end

@context PlaybackCtx
function Cassette.prehook(
    ctx::PlaybackCtx, ::kwftype(typeof(request)), kwargs, ::typeof(request),
    m::HTTPMethod, u, h=Header[], b=nobody,
)
    prehook(
        ctx,
        request,
        m,
        request_uri(u, get(kwargs, :query, nothing)),
        get(kwargs, :headers, h),
        get(kwargs, :body, b),
    )
end
function Cassette.prehook(
    ctx::PlaybackCtx, ::typeof(request), m::HTTPMethod, u, h=Header[], body=nobody,
)
    method = string(m)
    uri = request_uri(u, nothing)
    headers = mkheaders(h)
    isempty(ctx.metadata.responses) && error("No responses remaining in the data file")
    response = ctx.metadata.responses[1]
    request = response.request
    check_body(request, body)
    check_method(request, method)
    check_headers(request, headers; ignore=ctx.metadata.ignore_headers)
    check_uri(request, uri; ignore=ctx.metadata.ignore_query)
end
function Cassette.overdub(
    ctx::PlaybackCtx, ::kwftype(typeof(request)), k, ::typeof(request),
    m::HTTPMethod, u, h=Header[], b=nobody,
)
    return overdub(ctx, request, m, u, h, b)
end
Cassette.overdub(ctx::PlaybackCtx, ::typeof(request), ::HTTPMethod, u, h, b) =
    popfirst!(ctx.metadata.responses)
after(::PlaybackCtx, path) = nothing

"""
    playback(f, path; ignore_headers=[], ignore_query=[])

TODO
"""
function playback(f, path; ignore_headers=[], ignore_query=[])
    metadata = (; responses=[], ignore_headers=ignore_headers, ignore_query=ignore_query)
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

end
