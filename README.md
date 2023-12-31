# Protobuf.lua

> [!NOTE]  
> This library is still experimental and might not work perfectly in all scenarios.

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
