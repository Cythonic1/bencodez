# 📄 README.md

## 📦 Bencode Parser for Zig

A Zig implementation of a Bencode parser for decoding `.torrent` files and similar Bencode-encoded data.

---

## 🧠 Overview

This library provides a robust parser for **Bencode** (BitTorrent decoding) data. It supports parsing integers, strings, lists, and dictionaries (maps) from Bencode-encoded byte streams.

---

## 📦 Installation

Ensure you have [Zig](https://ziglang.org/) installed. To use this library in your project:

1. **Install via Git**: Clone the repository:
```bash
zig fetch --save "git+https://github.com/Cythonic1/bencodez#master"
```

2. **Configure `build.zig`**: Add the following to your project's `build.zig` to use this library:
```zig
const bencodez = b.dependency("bencodez", .{
        .target = target,
        .optimize = optimize,
        });

exe.root_module.addImport("bencodez", bencodez.module("bencodez"));
```


---

## 🧩 Usage Example

```zig
const std = @import("std");
const BencodeModule = @import("bencodez");
const Bencode = BencodeModule.Bencode;

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
const bencode_data = "d8:announce20:https://example.com/12:created_timei1698765432e4:infod8:filename4:file6:lengthi1234567890eee";

    // Initialize the parser with a byte buffer
    var parser = try Bencode.initWithBuf(allocator, bencode_data);
    defer parser.deinit();

    // Parse the Bencode data
    const parsed = try parser.parse();

    // Access parsed values
    const root = parsed[0].dict;
    const announce = root.get("announce").?.byte_string;
    const created_time = root.get("created_time").?.int;
    const info = root.get("info").?.dict;
    _ = info;

    std.debug.print("Announce URL: {s}\n", .{announce});
    std.debug.print("Created Time: {d}\n", .{created_time});
}
```

---


## 📚 API Reference

### `Bencode` Struct
- `initWithFile(io: Io, allocator: mem.Allocator, file_name: []const u8)`: Initialize parser from a file.
- `initWithBuf(allocator: mem.Allocator, bencoded: []const u8)`: Initialize parser from a byte buffer.
- `parse()`: Parse the Bencode data and return a list of `Value` objects.

### `Value` Union
- `.int`: Integer value (i64)
- `.byte_string`: String value ([]const u8)
- `.list`: List of `Value` objects
- `.dict`: Dictionary (StringHashMap of `Value`)

---

## 🛠️ Notes

- The parser uses Zig's standard library for memory management.
- Error handling is robust, with detailed error types for malformed input.
- The library is designed to be efficient and memory-safe.

---

## 📌 License

MIT License
See [LICENSE](LICENSE) for details.

---
