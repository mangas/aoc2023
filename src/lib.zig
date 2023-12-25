const std = @import("std");

pub fn readFile(ally: std.mem.Allocator, filename: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();
    return try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
}
