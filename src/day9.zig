const std = @import("std");
const lib = @import("lib.zig");

const Seq = std.ArrayList(i64);

fn calculateSeqFirst(ally: std.mem.Allocator, seq: Seq) anyerror!i64 {
    if (seq.items.len == 0) return 0;
    if (seq.items.len == 1) return seq.items[0];

    var diff = Seq.init(ally);
    defer diff.deinit();

    var is_zero: bool = true;
    var i: usize = 1;
    while (i < seq.items.len) : (i += 1) {
        try diff.append(seq.items[i] - seq.items[i - 1]);
        is_zero = is_zero and diff.items[i - 1] == 0;
    }
    const res = seq.items[0];

    if (is_zero) return res;

    return res - try calculateSeqFirst(ally, diff);
}

fn calculateSeqNext(ally: std.mem.Allocator, seq: Seq) anyerror!i64 {
    if (seq.items.len == 0) return 0;
    if (seq.items.len == 1) return seq.items[0];

    var diff = Seq.init(ally);
    defer diff.deinit();

    var is_zero: bool = true;
    var i: usize = 1;
    while (i < seq.items.len) : (i += 1) {
        try diff.append(seq.items[i] - seq.items[i - 1]);
        is_zero = is_zero and diff.items[i - 1] == 0;
    }
    const res = seq.items[seq.items.len - 1];

    if (is_zero) return res;

    return res + try calculateSeqNext(ally, diff);
}

fn decodeLines(ally: std.mem.Allocator, lines: []const u8) ![]Seq {
    var it = std.mem.splitSequence(u8, lines, "\n");

    var res = std.ArrayList(Seq).init(ally);
    defer res.deinit();
    while (it.next()) |line| {
        var seq = Seq.init(ally);

        var ns = std.mem.splitSequence(u8, line, " ");
        while (ns.next()) |n| {
            if (std.mem.trim(u8, n, " ").len == 0) continue;

            try seq.append(try std.fmt.parseInt(i64, n, 10));
        }

        try res.append(seq);
    }

    return res.toOwnedSlice();
}

fn sumLines(ally: std.mem.Allocator, lines: []Seq, comptime f: fn (std.mem.Allocator, Seq) anyerror!i64) !i64 {
    var sum: i64 = 0;
    for (lines) |line| {
        sum += try f(ally, line);
    }

    return sum;
}

test "day9 calibration example" {
    const ally = std.testing.allocator;
    const lines = "0 3 6 9 12 15";

    const decoded = try decodeLines(ally, lines);
    defer ally.free(decoded);
    defer {
        for (decoded) |seq|
            seq.deinit();
    }

    const sum = try sumLines(ally, decoded, calculateSeqNext);
    const expected: i64 = 18;
    try std.testing.expectEqual(expected, sum);
}

test "day9 calibration input" {
    const ally = std.testing.allocator;
    const lines =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    const decoded = try decodeLines(ally, lines);
    defer ally.free(decoded);
    defer {
        for (decoded) |seq|
            seq.deinit();
    }

    const sum = try sumLines(ally, decoded, calculateSeqNext);
    const expected: i64 = 114;
    try std.testing.expectEqual(expected, sum);
}

test "day9 input 1" {
    const ally = std.testing.allocator;
    const lines = try lib.readFile(ally, "inputs/day9.txt");
    defer ally.free(lines);

    const decoded = try decodeLines(ally, lines);
    defer ally.free(decoded);
    defer {
        for (decoded) |seq|
            seq.deinit();
    }

    const sum: i64 = try sumLines(ally, decoded, calculateSeqNext);
    const expected: i64 = 1980437560;
    try std.testing.expectEqual(expected, sum);
}

test "day9 calibration example part2" {
    const ally = std.testing.allocator;
    const lines = "10 13 16 21 30 45";

    const decoded = try decodeLines(ally, lines);
    defer ally.free(decoded);
    defer {
        for (decoded) |seq|
            seq.deinit();
    }

    const sum = try sumLines(ally, decoded, calculateSeqFirst);
    const expected: i64 = 5;
    try std.testing.expectEqual(expected, sum);
}

test "day9 input part2" {
    const ally = std.testing.allocator;
    const lines = try lib.readFile(ally, "inputs/day9.txt");
    defer ally.free(lines);

    const decoded = try decodeLines(ally, lines);
    defer ally.free(decoded);
    defer {
        for (decoded) |seq|
            seq.deinit();
    }

    const sum: i64 = try sumLines(ally, decoded, calculateSeqFirst);
    const expected: i64 = 977;
    try std.testing.expectEqual(expected, sum);
}
