struct RecordingLayer end

before(::Type{RecordingLayer}, storage, path) = nothing

function recordinglayer(handler)
    function record(req; kw...)
        resp = handler(req; kw...)
        state = get_state()
        push!(state.responses, deepcopy(resp))
        return resp
    end
end

function after(::Type{RecordingLayer}, storage, path)
    state = get_state()
    for resp in state.responses
        filter!(drop_keys(state.ignore_headers), resp.request.headers)
        filter!(drop_keys(state.ignore_headers), resp.headers)
        resp.request.target = filter_query(resp.request, state.ignore_query)
    end
    mkpath(dirname(path))
    store(storage, path; responses=state.responses, format=FORMAT)
end

function filter_query(request, ignore)
    uri = URI(request.target)
    query = filter(drop_keys(ignore), parse_query(uri))
    return if isempty(query)
        uri.path
    else
        uri.path * '?' * join((join(p, '=') for p in query), '&')
    end
end
