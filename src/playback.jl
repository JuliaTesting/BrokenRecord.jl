struct PlaybackLayer end

const NoQuery = Dict{SubString{String}, SubString{String}}

function before(::Type{PlaybackLayer}, storage, path)
    data = load(storage, path)
    state = get_state()
    append!(state.responses, data[:responses])
end

function playbacklayer(handler)
    function playback(req; kw...)
        state = get_state()
        isempty(state.responses) && error("No responses remaining in the data file")
        response = popfirst!(state.responses)
        request = response.request
        check_body(request, req.body)
        check_method(request, req.method)
        check_headers(request, req.headers; ignore=state.ignore_headers)
        check_uri(request, req.url; ignore=state.ignore_query)
        return response
    end
end

function after(::Type{PlaybackLayer}, storage, path)
    state = get_state()
    isempty(state.responses) || error("Found unused responses")
end

function check_body(request, body)
    if request.body == b"[Message Body was streamed]"
        @warn "Can't verify streamed request body"
    else
        request.body == body || error("Request body does not match")
    end
end

check_method(request, method) =
    request.method == method || error("Expected $(request.method) request, got $method")

function check_headers(request, headers; ignore)
    observed = filter(drop_keys(ignore), headers)
    # We only check for subset here because the `request` pipeline adds some headers
    # that the user didn't explicitly provide (Content-Length, Host, User-Agent).
    issubset(observed, request.headers) || error("Request headers do not match")
end

parse_query(uri) = isempty(uri.query) ? NoQuery() : Dict(split.(split(uri.query, '&'), '='))

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
