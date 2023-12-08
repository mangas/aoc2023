const std = @import("std");
const WINNER_SIZE: usize = 5;

const Card = struct {
    const Self = @This();

    number: u16,
    winners: NumberList,
    sequence: NumberList,

    pub fn init(number: u16, winners: NumberList, sequence: NumberList) Self {
        return .{
            .number = number,
            .winners = winners,
            .sequence = sequence,
        };
    }

    pub fn deinit(self: *Self) void {
        self.winners.deinit();
        self.sequence.deinit();
    }
};

const NumberList = std.ArrayList(u8);
const CardList = std.ArrayList(Card);

fn parseNumbers(ally: std.mem.Allocator, line: []const u8) !NumberList {
    var nl = NumberList.init(ally);
    var it = std.mem.splitSequence(u8, line, " ");

    while (it.next()) |str| {
        const n_str = std.mem.trim(u8, str, " ");
        if (n_str.len == 0) {
            continue;
        }

        const n = try std.fmt.parseInt(u8, n_str, 10);
        try nl.append(n);
    }

    return nl;
}

fn calibrationValue(cards: CardList) u64 {
    var sum: u64 = 0;
    for (cards.items) |card| {
        var count: u8 = 0;
        for (card.winners.items) |winner|
            for (card.sequence.items) |n| {
                if (n == winner) {
                    count += 1;
                    break;
                }
            };
        if (count == 0) continue;
        sum += std.math.pow(u64, 2, @as(u64, count - 1));
    }

    return sum;
}

fn calibrationValueExtended(cards: []Card, end_index: ?u64) u64 {
    const initial_cards = if (end_index == null) cards.len else 0;
    const end = end_index orelse cards.len;
    var sum: u64 = 0;
    for (cards[0..end], 0..) |card, i| {
        var count: u8 = 0;
        for (card.winners.items) |winner|
            for (card.sequence.items) |n| {
                if (n == winner) {
                    count += 1;
                    break;
                }
            };
        if (count == 0) continue;
        sum += count + calibrationValueExtended(
            cards[i + 1 ..],
            count,
        );
    }

    return initial_cards + sum;
}

fn decodeLines(
    ally: std.mem.Allocator,
    line: []const u8,
) !CardList {
    var res = CardList.init(ally);
    const colon: usize = std.mem.indexOfScalar(u8, line, ':') orelse unreachable;
    const pipe: usize = std.mem.indexOfScalar(u8, line, '|') orelse unreachable;
    var it = std.mem.splitSequence(u8, line, "\n");

    var i: u16 = 0;
    while (it.next()) |card_line| {
        if (std.mem.trim(u8, card_line, " ").len == 0) continue;
        const left = try parseNumbers(ally, card_line[colon + 1 .. pipe]);
        const right = try parseNumbers(ally, card_line[pipe + 1 .. card_line.len]);

        try res.append(Card.init(i, left, right));
        i += 1;
    }

    return res;
}

const Case = struct {
    winners: []const u8,
    sequence: []const u8,
};

test "day 4 calibration decode" {
    const ally = std.testing.allocator;
    const lines =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    const expected = [_]Case{
        .{
            .winners = &[_]u8{ 41, 48, 83, 86, 17 },
            .sequence = &[_]u8{ 83, 86, 6, 31, 17, 9, 48, 53 },
        },
        .{
            .winners = &[_]u8{ 13, 32, 20, 16, 61 },
            .sequence = &[_]u8{ 61, 30, 68, 82, 17, 32, 24, 19 },
        },
        .{
            .winners = &[_]u8{ 1, 21, 53, 59, 44 },
            .sequence = &[_]u8{ 69, 82, 63, 72, 16, 21, 14, 1 },
        },
        .{
            .winners = &[_]u8{ 41, 92, 73, 84, 69 },
            .sequence = &[_]u8{ 59, 84, 76, 51, 58, 5, 54, 83 },
        },
        .{
            .winners = &[_]u8{ 87, 83, 26, 28, 32 },
            .sequence = &[_]u8{ 88, 30, 70, 12, 93, 22, 82, 36 },
        },
        .{
            .winners = &[_]u8{ 31, 18, 13, 56, 72 },
            .sequence = &[_]u8{ 74, 77, 10, 23, 35, 67, 36, 11 },
        },
    };

    const cards = try decodeLines(ally, lines);
    defer cards.deinit();
    for (cards.items, 0..) |*card, i| {
        defer card.deinit();

        const winners = try card.winners.toOwnedSlice();
        defer ally.free(winners);
        const sequence = try card.sequence.toOwnedSlice();
        defer ally.free(sequence);

        try std.testing.expectEqualSlices(u8, expected[i].winners, winners);
        try std.testing.expectEqualSlices(u8, expected[i].sequence, sequence);
    }
}

test "day 4 calibration calc" {
    const ally = std.testing.allocator;
    const lines =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    var cards = try decodeLines(ally, lines);
    defer cards.deinit();
    defer for (cards.items) |*card| {
        card.deinit();
    };

    const expected: u64 = 13;
    const res = calibrationValue(cards);
    try std.testing.expectEqual(expected, res);
}

test "day 4 puzzle" {
    const ally = std.testing.allocator;
    const file = try std.fs.cwd().openFile("inputs/day4.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
    defer ally.free(lines);

    var cards = try decodeLines(ally, lines);
    defer cards.deinit();
    defer for (cards.items) |*card| {
        card.deinit();
    };

    const expected: u64 = 27454;
    const res = calibrationValue(cards);
    try std.testing.expectEqual(expected, res);
}

test "day 4 calibration extended" {
    const ally = std.testing.allocator;
    const lines =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    var cards = try decodeLines(ally, lines);

    const cards_slice = try cards.toOwnedSlice();
    defer ally.free(cards_slice);
    defer {
        for (cards_slice) |*card| {
            card.deinit();
        }
    }

    const expected: u64 = 30;
    const res = calibrationValueExtended(cards_slice, null);
    try std.testing.expectEqual(expected, res);
}

test "day 4 puzzle extended" {
    const ally = std.testing.allocator;
    const file = try std.fs.cwd().openFile("inputs/day4.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
    defer ally.free(lines);

    var cards = try decodeLines(ally, lines);

    const cards_slice = try cards.toOwnedSlice();
    defer ally.free(cards_slice);
    defer {
        for (cards_slice) |*card| {
            card.deinit();
        }
    }

    const expected: u64 = 27454;
    const res = calibrationValueExtended(cards_slice, null);
    try std.testing.expectEqual(expected, res);
}
