--[[
    Simple Lua Protobuf decoder
    Author: LNX (github.com/lnx00)
    https://protobuf.dev/
]]

local Protobuf = {}

local E_WireType = {
    Varint = 0,
    Fixed64 = 1,
    LengthDelimited = 2,
    StartGroup = 3,
    EndGroup = 4,
    Fixed32 = 5
}

---@param valueTable table<integer, any>
---@param fieldNumber integer
---@param value any
local function updateValue(valueTable, fieldNumber, value)
    local curValue = valueTable[fieldNumber]

    if curValue then
        -- Append the value (Repeated field)
        if type(curValue) == "table" and curValue._type == "repeated" then
            table.insert(curValue, value)
        else
            valueTable[fieldNumber] = { curValue, value }
            valueTable[fieldNumber]._type = "repeated"
        end
    else
        -- Insert the new value
        valueTable[fieldNumber] = value
    end
end

local function get32bit(data, offset)
    local value, toByte = 0, string.byte
    value = toByte(data, offset) | (toByte(data, offset + 1) << 8) | (toByte(data, offset + 2) << 16) |
        (toByte(data, offset + 3) << 24)
    return value
end

local function decodeVarint(data, offset)
    local value, shift = 0, 0

    repeat
        local byte = string.byte(data, offset)
        value = value + ((byte & 0x7F) << shift)
        shift = shift + 7
        offset = offset + 1
    until byte < 128

    return value, offset
end

local function decodeFixed32(data, offset)
    return get32bit(data, offset), offset + 4
end

local function decodeFixed64(data, offset)
    local value = get32bit(data, offset)
    offset = offset + 4
    value = value | (get32bit(data, offset) << 32)
    offset = offset + 4

    return value, offset
end

local function decodeLengthDelimited(data, offset)
    local length = 0
    length, offset = decodeVarint(data, offset)

    local value = string.sub(data, offset, offset + length - 1)
    offset = offset + length

    return value, offset
end

---@param data string
---@param offset integer
local function decodeProtobuf(data, offset)
    local tag, fieldNumber, wireType = 0, 0, 0
    local result = {}
    local value = nil

    while offset < #data do
        tag, offset = decodeVarint(data, offset)

        fieldNumber = tag >> 3
        wireType = tag & 0x07

        -- Decode the value
        if wireType == E_WireType.Varint then
            value, offset = decodeVarint(data, offset)
            updateValue(result, fieldNumber, value)
        elseif wireType == E_WireType.Fixed64 then
            value, offset = decodeFixed64(data, offset)
            updateValue(result, fieldNumber, value)
        elseif wireType == E_WireType.LengthDelimited then
            value, offset = decodeLengthDelimited(data, offset)

            -- Sub protobuf message
            if string.byte(value, 1) == 0x0A then
                value = decodeProtobuf(value, 1)
            end

            updateValue(result, fieldNumber, value)
        elseif wireType == E_WireType.StartGroup then
            offset = offset + 1
        elseif wireType == E_WireType.EndGroup then
            offset = offset + 1
        elseif wireType == E_WireType.Fixed32 then
            value, offset = decodeFixed32(data, offset)
            updateValue(result, fieldNumber, value)
        else
            print("Unknown wire type: " .. wireType)
            break
        end
    end

    result._type = "protobuf"
    return result
end

---Decodes a protobuf message and returns a table with the values
---@param data string
---@param offset? integer
---@return table<integer, any>
function Protobuf.Decode(data, offset)
    offset = offset or 1
    return decodeProtobuf(data, offset)
end

---Dumps the data in hex format
---@param data string
function Protobuf.Dump(data)
    local bytes = {}
    for i = 1, #data do
        local byte = string.byte(data, i)
        bytes[i] = string.format("%02X", byte)
    end

    print(table.concat(bytes, " "))
end

return Protobuf
