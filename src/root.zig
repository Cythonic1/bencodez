const std = @import("std");
const testing = std.testing;
const Bencode = @import("bencode.zig").Bencode;

test "init bencode with absolute file" {
    const io = testing.io;
    const allocator = testing.allocator;
    const bencode = try Bencode.init(io, allocator, "/home/pythonic/Desktop/zig/bencodez/assets/archlinux-2026.11.01-x86_64.iso.torrent");
    bencode.deinit(allocator);
}

test "init bencode with relative path" {
    const io = testing.io;
    const allocator = testing.allocator;
    const bencode = try Bencode.init(io, allocator, "assets/archlinux-2026.11.01-x86_64.iso.torrent");
    bencode.deinit(allocator);
}
