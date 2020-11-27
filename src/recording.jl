abstract type RecordingLayer{Next <: Layer} <: Layer{Next} end

before(::Type{<:RecordingLayer}, storage, path) = nothing

function HTTP.request(::Type{RecordingLayer{Next}}, resp) where Next
    state = get_state()
    push!(state.responses, deepcopy(resp))
    return request(Next, resp)
end

function after(::Type{<:RecordingLayer}, storage, path)
    state = get_state()
    for resp in state.responses
        filter!(drop_keys(state.ignore_headers), resp.request.headers)
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
