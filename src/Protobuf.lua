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

---Inserts new values or appends repeated values to the table
---@param valueTable table
---@param fieldNumber integer
---@param value any
local function updateValue(valueTable, fieldNumber, value)
    local curValue = valueTable[fieldNumber]

    if curValue then
        if type(curValue) == "table" and curValue._type == "repeated" then
            -- Append to repeated value
            table.insert(curValue, value)
        else
            -- Convert to repeated value
            valueTable[fieldNumber] = { curValue, value }
            valueTable[fieldNumber]._type = "repeated"
        end
    else
        -- Insert new value
        valueTable[fieldNumber] = value
        valueTable._size = (valueTable._size or 0) + 1
    end
end

---Returns a 32 bit integer from the data
---@param data string
---@param offset integer
local function get32bit(data, offset)
    local value, toByte = 0, string.byte
    value = toByte(data, offset) | (toByte(data, offset + 1) << 8) | (toByte(data, offset + 2) << 16) |
        (toByte(data, offset + 3) << 24)
    return value
end

---Decodes a varint value
---@param data string
---@param offset integer
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

---Decodes a 32 bit fixed value
---@param data string
---@param offset integer
local function decodeFixed32(data, offset)
    return get32bit(data, offset), offset + 4
end

---Decodes a 64 bit fixed value
---@param data string
---@param offset integer
local function decodeFixed64(data, offset)
    local value = get32bit(data, offset)
    offset = offset + 4
    value = value | (get32bit(data, offset) << 32)
    offset = offset + 4

    return value, offset
end

---Decodes a length delimited value
---This is used for strings and sub protobuf messages
---@param data string
---@param offset integer
local function decodeLengthDelimited(data, offset)
    local length = 0
    length, offset = decodeVarint(data, offset)

    local value = string.sub(data, offset, offset + length - 1)
    offset = offset + length

    return value, offset
end

---Decodes a protobuf message
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
---@return string
function Protobuf.Dump(data)
    local bytes = {}
    for i = 1, #data do
        local byte = string.byte(data, i)
        bytes[i] = string.format("%02X", byte)
    end

    return table.concat(bytes, " ")
end

return Protobuf
