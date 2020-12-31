abstract type RecordingLayer{Next <: Layer} <: Layer{Next} end

before(::Type{<:RecordingLayer}, ctx, path) = setfield!(ctx, :recording, true)

function HTTP.request(::Type{RecordingLayer{Next}}, resp) where Next
    ctx = get_context()
    push!(getfield(ctx, :responses), deepcopy(resp))
    return request(Next, resp)
end

function after(::Type{<:RecordingLayer}, ctx, path)
    for resp in ctx.responses
        filter!(drop_keys(getfield(ctx, :ignore_headers)), resp.request.headers)
        filter!(drop_keys(getfield(ctx, :ignore_headers)), resp.headers)
        resp.request.target = filter_query(resp.request, getfield(ctx, :ignore_query))
    end
    mkpath(dirname(path))
    store(
        getfield(ctx, :storage), path;
        responses=getfield(ctx, :responses), meta=getfield(ctx, :meta), format=FORMAT,
    )
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
