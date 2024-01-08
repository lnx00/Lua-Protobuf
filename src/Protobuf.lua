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
            curValue._size = curValue._size + 1
        else
            -- Convert to repeated value
            local newValue = { curValue, value }
            newValue._type = "repeated"
            newValue._size = 2
            valueTable[fieldNumber] = newValue
        end
    else
        -- Insert new value
        valueTable[fieldNumber] = value
        valueTable._size = (valueTable._size or 0) + 1
    end
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

local function encodeVarint(value)
    local result = {}
    local byte = 0

    repeat
        byte = value & 0x7F
        value = value >> 7

        if value > 0 then
            byte = byte | 0x80
        end

        table.insert(result, string.char(byte))
    until value == 0

    return table.concat(result)
end

---Decodes a 32 bit fixed value
---@param data string
---@param offset integer
local function decodeFixed32(data, offset)
    return string.unpack("<I4", data, offset), offset + 4
end

---Decodes a 64 bit fixed value
---@param data string
---@param offset integer
local function decodeFixed64(data, offset)
    return string.unpack("<I8", data, offset), offset + 8
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
---@return table? result, string? error
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
                local errorMsg = nil
                value, errorMsg = decodeProtobuf(value, 1)
                if value == nil then return nil, errorMsg end
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
            return nil, "Unknown wire type: " .. wireType
        end
    end

    result._type = "protobuf"
    return result
end

---@param data table
---@return string?, string?
local function encodeProtobuf(data)
    local result = {}

    for fieldNumber, value in pairs(data) do
        if not tonumber(fieldNumber) then
            goto continue
        end

        if type(value) == "number" then
            local tag = (fieldNumber << 3) | E_WireType.Varint
            table.insert(result, encodeVarint(tag))
            table.insert(result, encodeVarint(value))
        elseif type(value) == "string" then
            local tag = (fieldNumber << 3) | E_WireType.LengthDelimited
            table.insert(result, encodeVarint(tag))
            table.insert(result, encodeVarint(#value))
            table.insert(result, value)
        elseif type(value) == "table" then
            if value._type == "repeated" then
                local subSize = value._size or #value
                for i = 1, subSize do
                    local tag = (fieldNumber << 3) | E_WireType.Varint
                    table.insert(result, encodeVarint(tag))
                    table.insert(result, encodeVarint(value[i]))
                end
            elseif value._type == "protobuf" then
                local tag = (fieldNumber << 3) | E_WireType.LengthDelimited
                table.insert(result, encodeVarint(tag))
                table.insert(result, encodeProtobuf(value))
            else
                return nil, "Unspecified sub table type"
            end
        end

        ::continue::
    end

    return table.concat(result)
end

---Decodes a protobuf message and returns a table with the values
---@param data string
---@param offset? integer
---@return table? result, string? error
function Protobuf.Decode(data, offset)
    offset = offset or 1
    return decodeProtobuf(data, offset)
end

---(Experimental) Encodes a table into a protobuf message
---@param data table
---@return string? result, string? error
function Protobuf.Encode(data)
    return encodeProtobuf(data)
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
