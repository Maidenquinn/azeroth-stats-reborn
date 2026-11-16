-- Data-only wire encoding keeps backup numbers out of the native save writer.
-- The client rounds numeric literals; strings preserve exact double mantissas.
local M = AzerothStatsReborn.SharedCodec
local limit = 128 * 1024 * 1024
function M.encodeStore(value)
    local chunks, nodes, visiting = {}, 0, {}
    local function emit(v, depth)
        nodes = nodes + 1
        assert(nodes <= 4000000 and depth <= 32, "Shared wire budget exceeded")
        local kind = type(v)
        if kind == "number" then
            assert(v == v and math.abs(v) < 1e100, "Invalid shared number")
            local token = M.numberToken(v)
            table.insert(chunks, "n" .. string.len(token) .. ":" .. token)
        elseif kind == "string" then
            table.insert(chunks, "s" .. string.len(v) .. ":" .. v)
        elseif kind == "boolean" then
            table.insert(chunks, v and "b1" or "b0")
        else
            assert(
                kind == "table" and not getmetatable(v) and not visiting[v],
                "Unsafe shared value"
            )
            visiting[v] = true
            local keys = {}
            for key in pairs(v) do
                assert(type(key) == "string" or type(key) == "number", "Unsafe shared key")
                table.insert(keys, key)
            end
            table.sort(keys, function(a, b)
                if type(a) ~= type(b) then
                    return type(a) == "number"
                end
                return a < b
            end)
            table.insert(chunks, "t" .. table.getn(keys) .. ":")
            for _, key in ipairs(keys) do
                emit(key, depth + 1)
                emit(v[key], depth + 1)
            end
            visiting[v] = nil
        end
    end
    local ok, reason = pcall(emit, value, 0)
    if not ok then
        return nil, reason
    end
    local result = table.concat(chunks)
    if string.len(result) > limit then
        return nil, "Shared wire size exceeded"
    end
    return result
end
function M.decodeStore(text)
    if type(text) ~= "string" or string.len(text) > limit then
        return nil, "Invalid shared wire size"
    end
    local cursor, nodes = 1, 0
    local function length()
        local stop = string.find(text, ":", cursor, true)
        assert(stop and stop - cursor <= 10, "Missing shared wire length")
        local raw = string.sub(text, cursor, stop - 1)
        assert(string.match(raw, "^%d+$"), "Invalid shared wire length")
        local n = tonumber(raw)
        assert(n and n <= limit, "Shared wire length exceeded")
        cursor = stop + 1
        return n
    end
    local function read(depth)
        nodes = nodes + 1
        assert(nodes <= 4000000 and depth <= 32, "Shared wire budget exceeded")
        local tag = string.sub(text, cursor, cursor)
        cursor = cursor + 1
        if tag == "t" then
            local count, out = length(), {}
            assert(count <= 4000000, "Shared table budget exceeded")
            for _ = 1, count do
                local key = read(depth + 1)
                assert(
                    (type(key) == "string" or type(key) == "number") and out[key] == nil,
                    "Invalid shared key"
                )
                out[key] = read(depth + 1)
            end
            return out
        elseif tag == "b" then
            local bit = string.sub(text, cursor, cursor)
            cursor = cursor + 1
            assert(bit == "0" or bit == "1", "Invalid shared boolean")
            return bit == "1"
        else
            assert(tag == "s" or tag == "n", "Invalid shared tag")
            local size = length()
            assert(cursor + size - 1 <= string.len(text), "Truncated shared wire")
            local value = string.sub(text, cursor, cursor + size - 1)
            cursor = cursor + size
            if tag == "s" then
                return value
            end
            if string.sub(value, 1, 1) == "i" then
                local integer = tonumber(string.sub(value, 2))
                assert(
                    integer
                        and integer == math.floor(integer)
                        and math.abs(integer) <= 9007199254740992
                        and M.numberToken(integer) == value,
                    "Invalid shared integer"
                )
                return integer
            end
            local exponent, mantissa = string.match(value, "^(%-?%d+):(%-?%d+)$")
            exponent, mantissa = tonumber(exponent), tonumber(mantissa)
            assert(
                exponent
                    and mantissa
                    and math.abs(exponent) <= 1074
                    and math.abs(mantissa) <= 9007199254740992,
                "Invalid shared double"
            )
            local result = math.ldexp(mantissa, exponent - 53)
            assert(
                result == result and math.abs(result) < 1e100 and M.numberToken(result) == value,
                "Noncanonical shared double"
            )
            return result
        end
    end
    local ok, value = pcall(read, 0)
    if not ok then
        return nil, value
    end
    if cursor ~= string.len(text) + 1 then
        return nil, "Trailing shared wire data"
    end
    return value
end
