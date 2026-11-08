const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const HashMap = std.AutoHashMap;

pub const Bencode = struct {
    file_buf: []u8,

    const Self = @This();

    pub fn init(io: Io, allocator: mem.Allocator, file_name: []const u8) !Self {
        const file_content = try Io.Dir.readFileAlloc(.cwd(), io, file_name, allocator, .unlimited);
        return Self{
            .file_buf = file_content,
        };
    }

    pub fn deinit(self: *const Self, allocator: mem.Allocator) void {
        allocator.free(self.file_buf);
    }

    pub fn parse() !Value {}
};

const Tokeniser = struct {
    pub fn parseInt(int: []const u8) ret(i64) {}
    pub fn parseByteString(string: []const u8) ret([]const u8) {}
    pub fn parseDict(dict: []const u8) ret(HashMap([]const u8, Value)) {}
    pub fn parseList(list: []const u8) ret([]Value) {}

    fn ret(comptime ret_type: type) type {
        return struct {
            value: ret_type,
            size: usize,
        };
    }
};

pub const Value = union(enum) {
    int: i64,
    byte_string: []const u8,
    list: []Value,
    dict: HashMap([]const u8, Value),
};
