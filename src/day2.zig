const std = @import("std");

const GameTracker = std.ArrayList(BallSet);

const COLOURS = [_][]const u8{ "red", "green", "blue" };
const BallSet = struct {
    const Self = @This();

    red: u8,
    green: u8,
    blue: u8,

    pub fn new() BallSet {
        return .{ .red = 0, .green = 0, .blue = 0 };
    }

    pub fn power(self: *const Self) u64 {
        return @as(u64, self.red) * self.blue * self.green;
    }

    pub fn combine(self: *Self, other: BallSet) void {
        self.red = @max(self.red, other.red);
        self.green = @max(self.green, other.green);
        self.blue = @max(self.blue, other.blue);
    }

    pub fn is_possible(self: *const Self, max: BallSet) bool {
        return self.red <= max.red and self.green <= max.green and self.blue <= max.blue;
    }
};

fn decodeLine(
    line: []const u8,
) BallSet {
    var it = std.mem.splitSequence(u8, line, ":");
    _ = it.next().?;
    var sets = std.mem.splitSequence(u8, it.next().?, ";");
    var res = BallSet.new();

    while (sets.next()) |set| {
        res.combine(parseSet(set));
    }

    return res;
}

fn parseSet(line: []const u8) BallSet {
    var sets = std.mem.splitSequence(u8, line, " ");
    var res = BallSet.new();

    while (true) {
        var nstr = sets.next() orelse break;
        nstr = std.mem.trim(u8, nstr, " ");
        if (nstr.len == 0) {
            continue;
        }
        const n = std.fmt.parseInt(u8, nstr, 10) catch unreachable;
        const colour = sets.next().?;

        var i: u8 = 0;
        for (COLOURS) |c| {
            if (std.mem.startsWith(u8, colour, c)) {
                break;
            }
            i += 1;
        }

        switch (i) {
            0 => res.red += n,
            1 => res.green += n,
            2 => res.blue += n,
            else => unreachable,
        }
    }

    return res;
}

fn calibrationValueExtended(lines: []const u8) u64 {
    var it = std.mem.splitSequence(u8, lines, "\n");

    var sum: u64 = 0;
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const result = decodeLine(line);
        sum += result.power();
    }

    return sum;
}

fn calibrationValue(lines: []const u8, max: BallSet) u64 {
    var it = std.mem.splitSequence(u8, lines, "\n");

    var sum: u64 = 0;
    var i: u8 = 1;
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const result = decodeLine(line);
        if (result.is_possible(max)) {
            sum += i;
        }

        i += 1;
    }

    return sum;
}

test "day2 calibration" {
    const lines =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    var it = std.mem.splitSequence(u8, lines, "\n");
    const expected =
        [_]BallSet{
        .{
            .red = 4,
            .blue = 6,
            .green = 2,
        },
        .{
            .red = 1,
            .blue = 4,
            .green = 3,
        },
        .{
            .red = 20,
            .blue = 6,
            .green = 13,
        },
        .{
            .red = 14,
            .blue = 15,
            .green = 3,
        },
        .{
            .red = 6,
            .blue = 2,
            .green = 3,
        },
    };

    var i: u8 = 0;
    while (it.next()) |line| {
        const result = decodeLine(line);

        try std.testing.expectEqual(result, expected[i]);
        i += 1;
    }

    const max = .{
        .red = 12,
        .blue = 14,
        .green = 13,
    };
    const expected_sum: u64 = 8;
    const sum: u64 = calibrationValue(lines, max);
    try std.testing.expectEqual(expected_sum, sum);
}

test "day2 calibration extended" {
    const lines =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    const values = [_]u64{ 48, 12, 1560, 630, 36 };

    var i: u8 = 0;
    var it = std.mem.splitSequence(u8, lines, "\n");
    while (it.next()) |line| {
        const sum: u64 = calibrationValueExtended(line);
        try std.testing.expectEqual(values[i], sum);
        i += 1;
    }

    const expected_sum: u64 = 2286;
    const sum: u64 = calibrationValueExtended(lines);
    try std.testing.expectEqual(expected_sum, sum);
}

test "day2 puzzle" {
    const file = try std.fs.cwd().openFile("inputs/day2.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(u32));
    defer std.testing.allocator.free(lines);

    const max = .{
        .red = 12,
        .blue = 14,
        .green = 13,
    };
    const expected_sum: u64 = 2265;
    const sum: u64 = calibrationValue(lines, max);
    try std.testing.expectEqual(expected_sum, sum);
}

test "Puzzle extended" {
    const file = try std.fs.cwd().openFile("inputs/day2.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(u32));
    defer std.testing.allocator.free(lines);

    const expected_sum: u64 = 64096;
    const sum: u64 = calibrationValueExtended(lines);
    try std.testing.expectEqual(expected_sum, sum);
}
