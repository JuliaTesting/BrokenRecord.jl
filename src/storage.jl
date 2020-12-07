abstract type AbstractStorage end

struct BSONStorage <: AbstractStorage end
struct JLD2Storage <: AbstractStorage end
struct JLSOStorage <: AbstractStorage end
struct JSONStorage <: AbstractStorage end
struct YAMLStorage <: AbstractStorage end

const EXTENSIONS = Dict(
    "bson" => BSONStorage,
    "jld2" => JLD2Storage,
    "jlso" => JLSOStorage,
    "json" => JSONStorage,
    "yml" => YAMLStorage,
    "yaml" => YAMLStorage,
)

function get_storage(path, default)
    _, ext = splitext(path)
    key = lowercase(isempty(ext) ? default : ext[2:end])
    haskey(EXTENSIONS, key) || throw(ArgumentError("Unknown extension $ext"))
    storage = EXTENSIONS[key]
    isempty(ext) && (path *= ".$default")
    return storage, path
end

function resp_to_dict(resp)
    req = resp.request
    return Dict(
        "status" => resp.status,
        "headers" => resp.headers,
        "body" => repr_body(resp.body),
        "version" => string(resp.version),
        "request" => Dict(
            "method" => req.method,
            "headers" => req.headers,
            "target" => req.target,
            "body" => repr_body(req.body),
            "txcount" => req.txcount,
            "version" => string(req.version),
        ),
    )
end

function dict_to_resp(dict)
    resp = Response()
    resp.status = dict["status"]
    resp.headers = dicts_to_pairs(dict["headers"])
    resp.body = Vector{UInt8}(dict["body"])
    resp.version = VersionNumber(dict["version"])
    resp.request.method = dict["request"]["method"]
    resp.request.body = Vector{UInt8}(dict["request"]["body"])
    resp.request.headers = dicts_to_pairs(dict["request"]["headers"])
    resp.request.target = dict["request"]["target"]
    resp.request.txcount = dict["request"]["txcount"]
    resp.request.version = VersionNumber(dict["request"]["version"])
    return resp
end

repr_body(body) = isvalid(String, body) ? String(body) : resp.body
dicts_to_pairs(dicts) = map(d -> first(pairs(d)), dicts)
write_json(path, data) = open(io -> JSON.print(io, data, 2), path, "w")

load(::Type{BSONStorage}, path) = BSON.load(path)
store(::Type{BSONStorage}, path; responses, format) =
    BSON.bson(path; responses=responses, format=format)

function load(::Type{JLD2Storage}, path)
    JLD2.@load path responses format
    return Dict(:responses => responses, :format => format)
end

store(::Type{JLD2Storage}, path; responses, format) = JLD2.@save path responses format

load(::Type{JLSOStorage}, path) = JLSO.load(path)
store(::Type{JLSOStorage}, path; responses, format) =
    JLSO.save(path, :responses => responses, :format => format)

for (Storage, load_fun, store_fun) in (
    (JSONStorage, JSON.parsefile, write_json),
    (YAMLStorage, YAML.load_file, YAML.write_file),
)
    @eval begin
        function load(::Type{$Storage}, path)
            data = $load_fun(path)
            return Dict(
                :responses => map(dict_to_resp, data["responses"]),
                :format => VersionNumber(data["format"]),
            )
        end

        function store(::Type{$Storage}, path; responses, format)
            data = Dict(
                :responses => map(resp_to_dict, responses),
                :format => string(format),
            )
            $store_fun(path, data)
        end
    end
end
