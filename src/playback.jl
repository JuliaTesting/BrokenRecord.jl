@context PlaybackCtx

const HTTPMethod = Union{AbstractString, Symbol}
const NoQuery = Dict{SubString{String}, SubString{String}}

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

after(ctx::PlaybackCtx, path) =
    isempty(ctx.metadata.responses) || error("Found unused responses")

parse_query(uri) = isempty(uri.query) ? NoQuery() : Dict(split.(split(uri.query, '&'), '='))

check_body(request, body) =
    request.body == Vector{UInt8}(body) || error("Request body does not match")

check_method(request, method) =
    request.method == method || error("Expected $(request.method) request, got $method")

function check_headers(request, headers; ignore)
    observed = filter(drop_keys(ignore), headers)
    # We only check for subset here because the `request` pipeline adds some headers
    # that the user didn't explicitly provide (Content-Length, Host, User-Agent).
    issubset(observed, request.headers) || error("Request headers do not match")
end

function check_uri(request, uri; ignore)
    # Check host.
    host = header(request, "Host")
    host == uri.host || error("Expected request to $host, got $(uri.host)")
    # Check path.
    expected = URI(request.target)
    path = isempty(uri.path) ? "/" : uri.path
    expected.path == path || error("Expected request to $(expected.path), got $(uri.path)")
    # Check query string parameters.
    expected_q = parse_query(expected)
    observed_q = filter(drop_keys(ignore), parse_query(uri))
    expected_q == observed_q || error("Query string parameters do not match")
end
