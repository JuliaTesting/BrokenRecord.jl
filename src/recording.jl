@context RecordingCtx

Cassette.posthook(ctx::RecordingCtx, resp, ::typeof(request), ::Type{Union{}}, args...) =
    push!(ctx.metadata.responses, deepcopy(resp))

function after(ctx::RecordingCtx, path)
    for resp in ctx.metadata.responses
        filter!(drop_keys(ctx.metadata.ignore_headers), resp.request.headers)
        resp.request.target = filter_query(resp.request, ctx.metadata.ignore_query)
    end
    mkpath(dirname(path))
    bson(path; responses=ctx.metadata.responses, format=FORMAT)
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
