const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const enums = std.enums;
const ascii = std.ascii;
const fmt = std.fmt;
const math = std.math;
const heap = std.heap;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Ctx = struct {
    arena: mem.Allocator,
    tmp: mem.Allocator,
};

pub const Bencode = struct {
    encoded_data_buf: []u8,
    arena: heap.ArenaAllocator,

    const Self = @This();

    pub fn initWithFile(io: Io, allocator: mem.Allocator, file_name: []const u8) !Self {
        var arena = heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const file_content = try Io.Dir.readFileAlloc(.cwd(), io, file_name, arena.allocator(), .unlimited);
        return Self{
            .encoded_data_buf = file_content,
            .arena = arena,
        };
    }

    pub fn initWithBuf(allocator: mem.Allocator, bencoded: []const u8) !Self {
        var arena = heap.ArenaAllocator.init(allocator);
        errdefer arena.deinit();

        const buf = try arena.allocator().dupe(u8, bencoded);

        return Self{
            .encoded_data_buf = buf,
            .arena = arena,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
        self.* = undefined;
    }

    pub fn parse(self: *Self) Tokeniser.Error![]Value {
        const ctx: Ctx = .{
            .arena = self.arena.allocator(),
            .tmp = self.arena.child_allocator,
        };
        var values: ArrayList(Value) = .empty;
        defer values.deinit(ctx.tmp);

        var index: usize = 0;
        while (index < self.encoded_data_buf.len) {
            const val = try Tokeniser.parseValue(ctx, self.encoded_data_buf[index..]);
            index += val.size;
            try values.append(ctx.tmp, val.value);
        }

        return try ctx.arena.dupe(Value, values.items);
    }

    // impl parse one
};

const Tokeniser = struct {
    const Error = error{
        InvalidStringNoColon,
        NoEndFind,
        UnknownTypeByte,
        InvalidDictKey,
        MissingValue,
        UnexpectedEnd,
    } || fmt.ParseIntError || mem.Allocator.Error;

    pub const BenTypes = enum(u8) {
        Int = 'i',
        List = 'l',
        Dict = 'd',
        String,

        pub fn getToken(byte: u8) Error!BenTypes {
            return switch (byte) {
                'i' => .Int,
                'l' => .List,
                'd' => .Dict,
                '0'...'9' => .String,
                else => Error.UnknownTypeByte,
            };
        }
    };

    pub fn parseValue(ctx: Ctx, buf: []const u8) Error!Ret {
        if (buf.len == 0) return Error.UnexpectedEnd;
        return switch (try BenTypes.getToken(buf[0])) {
            .Int => parseInt(buf),
            .String => parseByteString(buf),
            .List => parseList(ctx, buf),
            .Dict => parseDict(ctx, buf),
        };
    }

    pub fn parseInt(int: []const u8) !Ret {
        const end = mem.indexOfScalar(u8, int, 'e') orelse return Error.NoEndFind;
        return .{
            .value = .{ .int = try fmt.parseInt(i64, int[1..end], 10) },
            .size = end + 1,
        };
    }

    pub fn parseByteString(string: []const u8) Error!Ret {
        const colon = mem.indexOfScalar(u8, string, ':') orelse return Error.InvalidStringNoColon;
        const str_size = try fmt.parseInt(usize, string[0..colon], 10);

        const start = try math.add(usize, colon, 1);
        const end = try math.add(usize, start, str_size);
        if (end > string.len) return Error.UnexpectedEnd;

        return Ret{
            .value = .{ .byte_string = string[start..end] },
            .size = end,
        };
    }

    pub fn parseDict(ctx: Ctx, dict: []const u8) !Ret {
        var map: StringHashMap(Value) = .init(ctx.arena);
        var i: usize = 1;

        while (true) {
            if (i >= dict.len) return Error.NoEndFind;
            if (dict[i] == 'e') break; // End found;

            if (try BenTypes.getToken(dict[i]) != .String) return Error.InvalidDictKey;
            const key = try Tokeniser.parseByteString(dict[i..]);
            i += key.size;

            if (i >= dict.len or dict[i] == 'e') return Error.MissingValue;

            const val = try parseValue(ctx, dict[i..]);
            i += val.size;

            try map.put(key.value.byte_string, val.value);
        }

        return .{
            .value = .{ .dict = map },
            .size = i + 1,
        };
    }

    pub fn parseList(ctx: Ctx, list: []const u8) Error!Ret {
        var list_values: ArrayList(Value) = .empty;
        defer list_values.deinit(ctx.tmp);
        var i: usize = 1;
        while (true) {
            if (i >= list.len) return Error.NoEndFind;
            if (list[i] == 'e') break;
            const val = try parseValue(ctx, list[i..]);
            i += val.size;
            try list_values.append(ctx.tmp, val.value);
        }
        return .{
            .value = .{ .list = try ctx.arena.dupe(Value, list_values.items) },
            .size = i + 1,
        };
    }

    const Ret = struct {
        value: Value,
        size: usize,
    };
};

pub const Value = union(enum) {
    int: i64,
    byte_string: []const u8,
    list: []Value,
    dict: StringHashMap(Value),
};
