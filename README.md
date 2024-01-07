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

The result could look like this:

```lua
{
  0 = 1
  1 = 1234567890
  2 = "Hello, World!"
  3 = {
    1 = 180
    2 = 260
    _size = 2
    _type = "repeated"
  }
  _size = 4
  _type = "protobuf"
}
```
