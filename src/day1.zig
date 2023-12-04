const std = @import("std");
const expect = @import("std").testing.expect;

const stdout = std.io.getStdOut().writer();
const VALID_NUMBERS = [_]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' };
const VALID_NUMBERS_EXTENDED = [_]u8{ '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'o', 't', 'f', 's', 'e', 'n' };
const VALID_WORDS = [_][]const u8{ "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };

fn findNumber(line: []const u8, index: usize) ?u8 {
    const x = line[index];
    switch (x) {
        '0'...'9' => return x - '0',
        else => {
            var i: u8 = 1;
            for (VALID_WORDS) |word| {
                if (std.mem.startsWith(u8, line[index..], word)) {
                    return i;
                }
                i += 1;
            }
        },
    }

    return null;
}

fn decodeLineExtended(line: []const u8) u8 {
    var left_index: usize = std.mem.indexOfAny(u8, line, &VALID_NUMBERS_EXTENDED).?;
    const left = while (true) {
        if (findNumber(line, left_index)) |left| {
            break left;
        }
        left_index = std.mem.indexOfAny(u8, line[left_index + 1 ..], &VALID_NUMBERS_EXTENDED).? + left_index + 1;
    };

    var right_index = std.mem.lastIndexOfAny(u8, line[left_index..], &VALID_NUMBERS_EXTENDED).? + left_index;
    const right = while (true) {
        if (findNumber(line, right_index)) |right| {
            break right;
        }
        if (right_index <= left_index) {
            break left;
        }
        right_index = std.mem.lastIndexOfAny(u8, line[left_index..right_index], &VALID_NUMBERS_EXTENDED).? + left_index;
    };

    return (left * 10) + right;
}

fn decodeLine(line: []const u8) u8 {
    const left_index = std.mem.indexOfAny(u8, line, &VALID_NUMBERS);
    const right_index = std.mem.lastIndexOfAny(u8, line, &VALID_NUMBERS);

    return (line[left_index.?] - '0') * 10 + (line[right_index.?] - '0');
}

fn calibrationValue(lines: []const u8) u64 {
    var it = std.mem.splitSequence(u8, lines, "\n");

    var sum: u64 = 0;
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const result = decodeLine(line);
        sum += result;
    }

    return sum;
}

fn calibrationValueExtended(lines: []const u8) u64 {
    var it = std.mem.splitSequence(u8, lines, "\n");

    var sum: u64 = 0;
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const result = decodeLineExtended(line);
        sum += result;
    }

    return sum;
}
test "calibration" {
    const lines =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;
    var it = std.mem.splitSequence(u8, lines, "\n");
    const expected =
        [_]u8{ 12, 38, 15, 77 };

    var i: u8 = 0;
    while (it.next()) |line| {
        const result = decodeLineExtended(line);

        try std.testing.expectEqual(expected[i], result);
        i += 1;
    }

    const expected_sum: u64 = 142;
    const sum: u64 = calibrationValue(lines);
    try std.testing.expectEqual(expected_sum, sum);
}

test "calibration extended" {
    const lines =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
    ;
    var it = std.mem.splitSequence(u8, lines, "\n");
    const expected =
        [_]u8{ 29, 83, 13, 24, 42, 14, 76 };

    var i: u8 = 0;
    while (it.next()) |line| {
        const result = decodeLineExtended(line);

        try std.testing.expectEqual(result, expected[i]);
        i += 1;
    }

    const expected_sum: u64 = 281;
    const sum: u64 = calibrationValueExtended(lines);
    try std.testing.expectEqual(expected_sum, sum);
}

test "puzzle" {
    const file = try std.fs.cwd().openFile("inputs/day1.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(u32));
    defer std.testing.allocator.free(lines);

    const expected_sum: u64 = 55607;
    const sum: u64 = calibrationValue(lines);
    try std.testing.expectEqual(expected_sum, sum);
}

test "puzzle extended" {
    const file = try std.fs.cwd().openFile("inputs/day1.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(u32));
    defer std.testing.allocator.free(lines);

    const expected_sum: u64 = 55291;
    const sum: u64 = calibrationValueExtended(lines);
    try std.testing.expectEqual(expected_sum, sum);
}
