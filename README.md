# Protobuf.lua

Simple [Protocol Buffer](https://protobuf.dev/) decoder for Lua without the need of a .proto schema file.
This library is written in pure Lua and does not require a C module.

## Usage

Import the library:
```lua
local Protobuf = require("Protobuf")
```

Decode data into a table:
```lua
local result =  Protobuf.Decode(data, offset)
```
