const std = @import("std");
const testing = std.testing;
const becoded = @import("bencode.zig");
const Bencode = becoded.Bencode;
const Value = becoded.Value;

test "init bencode with absolute file" {
    const io = testing.io;
    const allocator = testing.allocator;
    const bencode = try Bencode.initWithFile(io, allocator, "/home/misabear/Desktop/zig/bencodez/assets/archlinux-2026.11.01-x86_64.iso.torrent");
    defer bencode.deinit(allocator);
}

test "init bencode with relative path" {
    const io = testing.io;
    const allocator = testing.allocator;
    const bencode = try Bencode.initWithFile(io, allocator, "assets/archlinux-2026.11.01-x86_64.iso.torrent");
    defer bencode.deinit(allocator);
}

// test "testing parse type discovery string" {
//     const allocator = testing.allocator;
//
//     const data = "8:announce";
//     const bencode = try Bencode.initWithBuf(allocator, data[0..]);
//     defer bencode.deinit(allocator);
//
//     const parsed = try bencode.parse(allocator);
//     defer Value.deinit(allocator, parsed);
//
//     try testing.expectEqual(.byte_string, std.meta.activeTag(parsed[0]));
//     try testing.expectEqualStrings("announce", parsed[0].byte_string);
// }
//
// test "testing parse type discovery int" {
//     const allocator = testing.allocator;
//
//     const data = "i8";
//     const bencode = try Bencode.initWithBuf(allocator, data[0..]);
//     defer bencode.deinit(allocator);
//
//     const parsed = try bencode.parse(allocator);
//     defer Value.deinit(allocator, parsed);
//
//     try testing.expectEqual(.int, std.meta.activeTag(parsed[0]));
//     try testing.expectEqual(8, parsed[0].int);
// }

test "parse strings and ints" {
    const allocator = testing.allocator;
    const input = "11:hello worldi42e3:fooi-7e0:";

    const bencode = try Bencode.initWithBuf(allocator, input[0..]);
    defer bencode.deinit(allocator);

    const parsed = try bencode.parse(allocator);
    defer Value.deinit(allocator, parsed);

    try testing.expectEqual(@as(usize, 5), parsed.len);
    try testing.expectEqualStrings("hello world", parsed[0].byte_string);
    try testing.expectEqual(@as(i64, 42), parsed[1].int);
    try testing.expectEqualStrings("foo", parsed[2].byte_string);
    try testing.expectEqual(@as(i64, -7), parsed[3].int);
    try testing.expectEqualStrings("", parsed[4].byte_string);
}
