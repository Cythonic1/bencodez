const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const enums = std.enums;
const ascii = std.ascii;
const fmt = std.fmt;
const ArrayList = std.ArrayList;
const HashMap = std.AutoHashMap;

pub const Bencode = struct {
    encoded_data_buf: []u8,
    allocator: mem.Allocator,

    const Self = @This();

    const BenTypes = enum(u8) {
        Int = 'i',
        List = 'l',
        Dict = 'd',
        String,

        fn getToken(byte: u8) Errors!BenTypes {
            const first_token = enums.fromInt(BenTypes, byte);
            if (first_token) |token| {
                return token;
            } else {
                if (ascii.isDigit(byte)) {
                    return BenTypes.String;
                } else {
                    return Errors.UnknownTypeByte;
                }
            }
        }
    };

    const Errors = error{
        MissingColon,
        UnknownTypeByte,
    } || mem.Allocator.Error || Tokeniser.Error || fmt.ParseIntError;

    pub fn initWithFile(io: Io, allocator: mem.Allocator, file_name: []const u8) !Self {
        const file_content = try Io.Dir.readFileAlloc(.cwd(), io, file_name, allocator, .unlimited);
        return Self{
            .encoded_data_buf = file_content,
            .allocator = allocator,
        };
    }

    pub fn initWithBuf(allocator: mem.Allocator, bencoded: []const u8) !Self {
        const buf = try allocator.alloc(u8, bencoded.len);
        mem.copyForwards(u8, buf, bencoded);
        return Self{
            .encoded_data_buf = buf,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const Self, allocator: mem.Allocator) void {
        allocator.free(self.encoded_data_buf);
    }

    pub fn parse(self: *const Self, allocator: mem.Allocator) Errors![]Value {
        var values = ArrayList(Value).empty;
        var index: usize = 0;

        while (index < self.encoded_data_buf.len) {
            const tokenType = try BenTypes.getToken(self.encoded_data_buf[index]);
            std.debug.print("Processing token {s}", .{@tagName(tokenType)});
            const parsed_value = brk: {
                switch (tokenType) {
                    .String => {
                        break :brk try Tokeniser.parseByteString(allocator, self.encoded_data_buf[index..]);
                    },
                    .Int => {
                        break :brk try Tokeniser.parseInt(self.encoded_data_buf[index..]);
                    },
                    else => {
                        std.log.err("not implemented", .{});
                        continue;
                    },
                }
            };

            try values.append(allocator, parsed_value.value);
            index += parsed_value.size;
            std.debug.print("processed length is {d}", .{parsed_value.size});
        }

        return values.toOwnedSlice(self.allocator);
    }
};

const Tokeniser = struct {
    const Ind = enum(u8) {
        EndOfValue = 'e',
    };

    const Error = error{
        InvalidStringNoColon,
    } || fmt.ParseIntError || mem.Allocator.Error;
    pub fn parseInt(int: []const u8) !Ret {
        return .{
            .value = .{ .int = try fmt.parseInt(i64, int[1..], 10) },
            .size = @sizeOf(i64),
        };
    }
    pub fn parseByteString(allocator: mem.Allocator, string: []const u8) Error!Ret {
        const colon = mem.indexOfScalar(u8, string, ':') orelse return Error.InvalidStringNoColon;
        const str_size = try fmt.parseInt(usize, string[0..colon], 10);

        const buf = try allocator.alloc(u8, str_size);
        const start = colon + 1;
        const end = start + str_size;

        std.debug.print("start = {} end = {}", .{start, end});
        @memcpy(buf, string[start..end]);

        return Ret{
            .value = .{ .byte_string = buf },
            .size = end,
        };
    }
    pub fn parseDict(dict: []const u8) Ret {
        _ = dict;
    }
    pub fn parseList(list: []const u8) Ret {
        _ = list;
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
    dict: HashMap([]const u8, Value),

    pub fn deinit(allocator: mem.Allocator, values: []Value) void {
        std.debug.print("{any}", .{values});
        for (values) |value| {
            switch (value) {
                .byte_string => |str| {
                    allocator.free(str);
                },
                else => {
                    std.log.debug("no need to free", .{});
                },
            }
        }
        allocator.free(values);
    }
};
