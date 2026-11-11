const std = @import("std");
const testing = std.testing;
const becoded = @import("bencode.zig");

pub const Bencode = becoded.Bencode;
pub const Value = becoded.Value;

// ============================================================================
// Helpers
// ============================================================================

fn expectParseError(expected: anyerror, input: []const u8) !void {
    const allocator = testing.allocator;
    var ben = try Bencode.initWithBuf(allocator, input);
    defer ben.deinit();

    const res = ben.parse();
    try testing.expectError(expected, res);
}

// ============================================================================
// Initialization
// ============================================================================

test "init: file with absolute path" {
    const io = testing.io;
    const allocator = testing.allocator;

    var bencode = try Bencode.initWithFile(io, allocator, "/home/misabear/Desktop/zig/bencodez/assets/archlinux-2026.11.01-x86_64.iso.torrent");
    defer bencode.deinit();
}

test "init: file with relative path" {
    const io = testing.io;
    const allocator = testing.allocator;

    var bencode = try Bencode.initWithFile(io, allocator, "assets/archlinux-2026.11.01-x86_64.iso.torrent");
    defer bencode.deinit();
}

// ============================================================================
// Scalars: strings and ints
// ============================================================================

test "scalar: string type discovery" {
    const allocator = testing.allocator;

    const data = "8:announce";
    var bencode = try Bencode.initWithBuf(allocator, data[0..]);
    defer bencode.deinit();

    const parsed = try bencode.parse();

    try testing.expectEqual(.byte_string, std.meta.activeTag(parsed[0]));
    try testing.expectEqualStrings("announce", parsed[0].byte_string);
}

test "scalar: int type discovery" {
    const allocator = testing.allocator;

    const data = "i8e";
    var bencode = try Bencode.initWithBuf(allocator, data[0..]);
    defer bencode.deinit();

    const parsed = try bencode.parse();

    try testing.expectEqual(.int, std.meta.activeTag(parsed[0]));
    try testing.expectEqual(8, parsed[0].int);
}

test "scalar: multiple strings and ints in sequence" {
    const allocator = testing.allocator;
    const input = "11:hello worldi42e3:fooi-7e0:";

    var bencode = try Bencode.initWithBuf(allocator, input[0..]);
    defer bencode.deinit();

    const parsed = try bencode.parse();

    try testing.expectEqual(@as(usize, 5), parsed.len);
    try testing.expectEqualStrings("hello world", parsed[0].byte_string);
    try testing.expectEqual(@as(i64, 42), parsed[1].int);
    try testing.expectEqualStrings("foo", parsed[2].byte_string);
    try testing.expectEqual(@as(i64, -7), parsed[3].int);
    try testing.expectEqualStrings("", parsed[4].byte_string);
}

// ============================================================================
// Scalar errors
// ============================================================================

test "errors: int" {
    try expectParseError(error.NoEndFind, "i42");
    try expectParseError(error.InvalidCharacter, "ie");
    try expectParseError(error.InvalidCharacter, "i-e");
    try expectParseError(error.InvalidCharacter, "i4.5e");
    try expectParseError(error.InvalidCharacter, "i4a2e");
    try expectParseError(error.InvalidCharacter, "i--5e");
    try expectParseError(error.InvalidCharacter, "i 42e");
    try expectParseError(error.Overflow, "i99999999999999999999e");
}

test "errors: string" {
    try expectParseError(error.InvalidStringNoColon, "5hello");
    try expectParseError(error.UnknownTypeByte, ":abc");
    try expectParseError(error.UnknownTypeByte, "-1:a");
    try expectParseError(error.UnknownTypeByte, "+5:hello");
    try expectParseError(error.UnknownTypeByte, "a:hello");
    try expectParseError(error.Overflow, "99999999999999999999:x");
    try expectParseError(error.Overflow, "18446744073709551615:x");
}

test "errors: unknown type byte" {
    try expectParseError(error.UnknownTypeByte, "x");
}

// ============================================================================
// Dicts
// ============================================================================

test "dict: empty" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "de");
    defer ben.deinit();

    const parsed = try ben.parse();

    try testing.expectEqual(@as(usize, 1), parsed.len);
    try testing.expectEqual(0, parsed[0].dict.count());
}

test "dict: simple string and int values" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "d3:agei30e4:name5:alicee");
    defer ben.deinit();

    const parsed = try ben.parse();

    try testing.expectEqual(@as(usize, 1), parsed.len);
    try testing.expectEqual(.dict, std.meta.activeTag(parsed[0]));
    try testing.expectEqual(2, parsed[0].dict.count());
    try testing.expectEqual(@as(i64, 30), parsed[0].dict.get("age").?.int);
    try testing.expectEqualStrings("alice", parsed[0].dict.get("name").?.byte_string);
}

test "dict: missing key returns null" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "d3:agei30ee");
    defer ben.deinit();

    const parsed = try ben.parse();
    try testing.expect(parsed[0].dict.get("name") == null);
}

test "dict: nested dict as value" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "d4:infod4:name5:alicee3:agei30ee");
    defer ben.deinit();

    const parsed = try ben.parse();

    try testing.expectEqual(@as(usize, 1), parsed.len);
    const root = parsed[0].dict;
    try testing.expectEqual(@as(i64, 30), root.get("age").?.int);

    const info = root.get("info").?.dict;
    try testing.expectEqual(1, info.count());
    try testing.expectEqualStrings("alice", info.get("name").?.byte_string);
}

test "dict: deeply nested" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "d1:ad1:bd1:ci1eeee");
    defer ben.deinit();

    const parsed = try ben.parse();

    const c = parsed[0].dict.get("a").?.dict.get("b").?.dict.get("c").?;
    try testing.expectEqual(@as(i64, 1), c.int);
}

test "dict: followed by other top-level values" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "d1:ai1ee3:fooi5e");
    defer ben.deinit();

    const parsed = try ben.parse();

    try testing.expectEqual(@as(usize, 3), parsed.len);
    try testing.expectEqual(@as(i64, 1), parsed[0].dict.get("a").?.int);
    try testing.expectEqualStrings("foo", parsed[1].byte_string);
    try testing.expectEqual(@as(i64, 5), parsed[2].int);
}

test "errors: dict" {
    // no closing 'e'
    try expectParseError(error.NoEndFind, "d");
    try expectParseError(error.NoEndFind, "d3:agei30e");
    // inner dict closes, outer never does
    try expectParseError(error.NoEndFind, "d1:ad1:bi1ee");
    // key is not a string
    try expectParseError(error.InvalidDictKey, "di1ei2ee");
    // key without a value
    try expectParseError(error.MissingValue, "d3:agee");
    try expectParseError(error.MissingValue, "d3:age");
    // value has an unknown type byte
    try expectParseError(error.UnknownTypeByte, "d3:agex");
    // key string longer than the buffer
    try expectParseError(error.UnexpectedEnd, "d5:ab");
}

// ============================================================================
// Lists
// ============================================================================

test "list: empty" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "le");
    defer ben.deinit();

    const parsed = try ben.parse();

    try testing.expectEqual(@as(usize, 1), parsed.len);
    try testing.expectEqual(.list, std.meta.activeTag(parsed[0]));
    try testing.expectEqual(@as(usize, 0), parsed[0].list.len);
}

test "list: single item" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "li-7ee");
    defer ben.deinit();

    const parsed = try ben.parse();

    try testing.expectEqual(@as(usize, 1), parsed[0].list.len);
    try testing.expectEqual(@as(i64, -7), parsed[0].list[0].int);
}

test "list: mixed strings and ints" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "l4:spam4:eggsi42ee");
    defer ben.deinit();

    const parsed = try ben.parse();
    const list = parsed[0].list;

    try testing.expectEqual(@as(usize, 1), parsed.len);
    try testing.expectEqual(@as(usize, 3), list.len);
    try testing.expectEqualStrings("spam", list[0].byte_string);
    try testing.expectEqualStrings("eggs", list[1].byte_string);
    try testing.expectEqual(@as(i64, 42), list[2].int);
}

test "list: empty string and empty list inside" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "l0:lee");
    defer ben.deinit();

    const parsed = try ben.parse();
    const list = parsed[0].list;

    try testing.expectEqual(@as(usize, 2), list.len);
    try testing.expectEqualStrings("", list[0].byte_string);
    try testing.expectEqual(@as(usize, 0), list[1].list.len);
}

test "list: nested lists" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "lli1ei2eel3:abcee");
    defer ben.deinit();

    const parsed = try ben.parse();
    const outer = parsed[0].list;

    try testing.expectEqual(@as(usize, 2), outer.len);

    const first = outer[0].list;
    try testing.expectEqual(@as(usize, 2), first.len);
    try testing.expectEqual(@as(i64, 1), first[0].int);
    try testing.expectEqual(@as(i64, 2), first[1].int);

    const second = outer[1].list;
    try testing.expectEqual(@as(usize, 1), second.len);
    try testing.expectEqualStrings("abc", second[0].byte_string);
}

test "list: deeply nested empty lists" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "llleee");
    defer ben.deinit();

    const parsed = try ben.parse();

    const l1 = parsed[0].list;
    try testing.expectEqual(@as(usize, 1), l1.len);
    const l2 = l1[0].list;
    try testing.expectEqual(@as(usize, 1), l2.len);
    try testing.expectEqual(@as(usize, 0), l2[0].list.len);
}

test "list: followed by other top-level values" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "li1ee3:fooi5e");
    defer ben.deinit();

    const parsed = try ben.parse();

    try testing.expectEqual(@as(usize, 3), parsed.len);
    try testing.expectEqual(@as(i64, 1), parsed[0].list[0].int);
    try testing.expectEqualStrings("foo", parsed[1].byte_string);
    try testing.expectEqual(@as(i64, 5), parsed[2].int);
}

test "errors: list" {
    // no closing 'e'
    try expectParseError(error.NoEndFind, "l");
    try expectParseError(error.NoEndFind, "li1e");
    try expectParseError(error.NoEndFind, "l4:spam");
    // inner list closes, outer never does
    try expectParseError(error.NoEndFind, "lli1ee");
    // list inside dict never closes
    try expectParseError(error.NoEndFind, "d1:ale");
    // bad item inside the list
    try expectParseError(error.UnknownTypeByte, "lx");
    try expectParseError(error.InvalidCharacter, "li4a2ee");
    // string item longer than the buffer
    try expectParseError(error.UnexpectedEnd, "l5:ab");
}

// ============================================================================
// Mixed nesting: lists and dicts together
// ============================================================================

test "mixed: list of dicts" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "ld1:ai1eed1:ai2eee");
    defer ben.deinit();

    const parsed = try ben.parse();
    const list = parsed[0].list;

    try testing.expectEqual(@as(usize, 2), list.len);
    try testing.expectEqual(@as(i64, 1), list[0].dict.get("a").?.int);
    try testing.expectEqual(@as(i64, 2), list[1].dict.get("a").?.int);
}

test "mixed: list inside dict" {
    const allocator = testing.allocator;

    var ben = try Bencode.initWithBuf(allocator, "d4:listl1:xi5eee");
    defer ben.deinit();

    const parsed = try ben.parse();
    const list = parsed[0].dict.get("list").?.list;

    try testing.expectEqual(@as(usize, 2), list.len);
    try testing.expectEqualStrings("x", list[0].byte_string);
    try testing.expectEqual(@as(i64, 5), list[1].int);
}

test "mixed: dict with list value followed by another key" {
    const allocator = testing.allocator;

    // the list's 'e' must not be mistaken for the dict's 'e'
    var ben = try Bencode.initWithBuf(allocator, "d1:ali1ee1:bi2ee");
    defer ben.deinit();

    const parsed = try ben.parse();
    const root = parsed[0].dict;

    try testing.expectEqual(@as(usize, 2), root.count());
    try testing.expectEqual(@as(i64, 1), root.get("a").?.list[0].int);
    try testing.expectEqual(@as(i64, 2), root.get("b").?.int);
}
