const std = @import("std");
const lib = @import("lib.zig");

const Pipe = enum {
    start,
    vertical,
    horizontal,
    northeast,
    northwest,
    southwest,
    southeast,
    ground,

    pub fn parse(c: u8) Pipe {
        return switch (c) {
            'S' => .start,
            '.' => .ground,
            '|' => .vertical,
            '-' => .horizontal,
            'L' => .northeast,
            'J' => .northwest,
            '7' => .southwest,
            'F' => .southeast,
            else => unreachable,
        };
    }
};

const Position = struct {
    pipe: Pipe,
    x: u32,
    y: u32,

    pub fn isConnected(self: *const Position, other: *const Position) bool {
        _ = self;
        _ = other;
    }
};

const Board = struct {
    board: [][]const u8,
    start: Position,

    pub fn process(self: *Board) u64 {
        _ = self;
    }

    pub fn pathsFrom(self: *Board, pos: Position) [2]Position {
        _ = self;
        _ = pos;
    }
};

pub fn decodeLines(ally: std.mem.Allocator, lines: []const u8) Board {
    var it = std.mem.splitSequence(u8, lines, "\n");
    var res = std.ArrayList([]const u8).init(ally);
    defer res.deinit();

    while (it.next()) |line| {
        try res.append(line);
    }

    return res.toOwnedSlice();
}

test "calibration example 1" {
    const lines =
        \\.....
        \\.S-7.
        \\.|.|.
        \\.L-J.
        \\.....
    ;
    _ = lines;
}
