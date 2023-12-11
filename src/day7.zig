const std = @import("std");

const HAND_SIZE: usize = 5;
const CARDS: []const u8 = &[_]u8{ 'A', 'K', 'Q', 'J', 'T', '9', '8', '7', '6', '5', '4', '3', '2' };
const CARDS_PART2: []const u8 = &[_]u8{ 'A', 'K', 'Q', 'T', '9', '8', '7', '6', '5', '4', '3', '2', 'J' };

fn cardsLessThan(cards: []const u8, left: u8, right: u8) bool {
    return std.mem.indexOfScalar(u8, cards, left).? > std.mem.indexOfScalar(u8, cards, right).?;
}

const HandType = enum {
    five_of_a_kind,
    four_of_a_kind,
    full_house,
    three_of_a_kind,
    two_pair,
    one_pair,
    high_card,

    pub fn withJokers(hand_t: HandType, jokers: u8) HandType {
        if (jokers == 0) return hand_t;

        return switch (hand_t) {
            .five_of_a_kind => .five_of_a_kind,
            .four_of_a_kind => .five_of_a_kind,
            .full_house => @enumFromInt(@intFromEnum(hand_t) - @min(jokers, 2)),
            .three_of_a_kind => @enumFromInt(@intFromEnum(HandType.full_house) - @min(jokers, 2)),
            .two_pair => @enumFromInt(@intFromEnum(HandType.three_of_a_kind) - @min(jokers, 2)),
            .one_pair => .three_of_a_kind,
            .high_card => .one_pair,
        };
    }

    pub fn fromCards(card_set: []const u8, hand: []const u8) ?HandType {
        var cards: [HAND_SIZE]u8 = undefined;
        @memcpy(&cards, hand);
        std.mem.sort(u8, &cards, card_set, comptime cardsLessThan);

        return fromSortedCards(cards, 0);
    }

    fn fromSortedCards(hand: [HAND_SIZE]u8, start: usize) ?HandType {
        if (start >= hand.len) return null;

        var previous: ?u8 = null;
        var count: u8 = 0;
        for (hand[start..]) |card| {
            const prev = previous orelse {
                previous = card;
                count += 1;
                continue;
            };

            if (card == prev) {
                count += 1;
                continue;
            }

            break;
        }

        return switch (count) {
            5 => return .five_of_a_kind,
            4 => return .four_of_a_kind,
            3 => {
                const next =
                    fromSortedCards(hand, start + count) orelse return .three_of_a_kind;
                switch (next) {
                    .one_pair => return .full_house,
                    else => return .three_of_a_kind,
                }
            },
            2 => {
                const next =
                    fromSortedCards(hand, start + count) orelse return .one_pair;
                return switch (next) {
                    .three_of_a_kind => .full_house,
                    .one_pair => .two_pair,
                    else => .one_pair,
                };
            },
            1 => {
                return fromSortedCards(hand, start + count) orelse .high_card;
            },
            else => {
                std.debug.print("count: {d}", .{count});
                unreachable;
            },
        };
    }
};

const Hand = struct {
    const Self = @This();

    jokers: u8 = 0,
    cards: []const u8,
    hand_type: HandType,

    pub fn init(cards: []const u8) Self {
        return Hand{
            .cards = cards,
            .hand_type = HandType.fromCards(CARDS, cards).?,
        };
    }

    pub fn init2(cards: []const u8) Self {
        const jokers: u8 = @as(u8, @intCast(std.mem.count(u8, cards, "J")));
        const hand_t = HandType.fromCards(CARDS_PART2, cards).?.withJokers(jokers);

        return Hand{
            .jokers = jokers,
            .cards = cards,
            .hand_type = hand_t,
        };
    }
};

const BidList = std.ArrayList(Bid);

const Bids = struct {
    bids: BidList,

    pub fn init2(bids: BidList) Bids {
        std.mem.sort(Bid, bids.items, CARDS_PART2, Bid.lessThan);

        return .{
            .bids = bids,
        };
    }

    pub fn init(bids: BidList) Bids {
        std.mem.sort(Bid, bids.items, CARDS, Bid.lessThan);

        return .{
            .bids = bids,
        };
    }

    pub fn winnings(self: Bids) u64 {
        var sum: u64 = 0;
        for (self.bids.items, 1..) |bid, rank| {
            sum += bid.bid * rank;
        }

        return sum;
    }
};

const Bid = struct {
    hand: Hand,
    bid: u64,

    pub fn lessThan(cards: []const u8, left: Bid, right: Bid) bool {
        {
            const idx_l = @intFromEnum(left.hand.hand_type);
            const idx_r = @intFromEnum(right.hand.hand_type);
            if (idx_l != idx_r)
                return idx_l > idx_r;
        }

        for (0..HAND_SIZE) |i| {
            const idx_l = std.mem.indexOfScalar(u8, cards, left.hand.cards[i]).?;
            const idx_r = std.mem.indexOfScalar(u8, cards, right.hand.cards[i]).?;

            if (idx_l == idx_r) continue;

            return idx_l > idx_r;
        }

        return false;
    }
};

fn decodeLines(
    ally: std.mem.Allocator,
    lines: []const u8,
    comptime handBuilder: fn ([]const u8) Hand,
) !BidList {
    var it = std.mem.splitSequence(u8, lines, "\n");

    var res: BidList = BidList.init(ally);
    //empty
    while (it.next()) |line| {
        if (line.len == 0) continue;
        var bid_it = std.mem.splitSequence(u8, line, " ");
        try res.append(.{
            .hand = handBuilder(bid_it.next().?),
            .bid = try std.fmt.parseInt(u64, bid_it.next().?, 10),
        });
    }

    return res;
}

test "day 7 calibration decode" {
    const ally = std.testing.allocator;
    const lines =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;

    const bids = try decodeLines(ally, lines, Hand.init);
    defer bids.deinit();
    const expected = &[_]Bid{
        .{
            .hand = .{
                .cards = "32T3K",
                .hand_type = .one_pair,
            },
            .bid = 765,
        },
        .{
            .hand = .{
                .cards = "T55J5",
                .hand_type = .three_of_a_kind,
            },
            .bid = 684,
        },
        .{
            .hand = .{
                .cards = "KK677",
                .hand_type = .two_pair,
            },
            .bid = 28,
        },
        .{
            .hand = .{
                .cards = "KTJJT",
                .hand_type = .two_pair,
            },
            .bid = 220,
        },
        .{
            .hand = .{
                .cards = "QQQJA",
                .hand_type = .three_of_a_kind,
            },
            .bid = 483,
        },
    };

    try std.testing.expectEqualDeep(expected, bids.items[0..5]);
}

test "day 7 calibration winnings" {
    const ally = std.testing.allocator;
    const lines =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;

    var bids_l = try decodeLines(ally, lines, Hand.init);
    defer bids_l.deinit();

    const bids = Bids.init(bids_l);

    const expected: u64 = 6440;
    try std.testing.expectEqualDeep(expected, bids.winnings());
}

test "bid less than" {
    const one: Bid =
        .{
        .hand = .{
            .cards = "T55J5",
            .hand_type = .three_of_a_kind,
            .jokers = 1,
        },
        .bid = 684,
    };

    const other: Bid =
        .{
        .hand = .{
            .cards = "QQQJA",
            .hand_type = .three_of_a_kind,
            .jokers = 1,
        },
        .bid = 483,
    };
    const pair: Bid =
        .{
        .hand = .{
            .cards = "QQJA3",
            .hand_type = .one_pair,
            .jokers = 0,
        },
        .bid = 483,
    };

    const l = Bid{ .hand = Hand{ .cards = "KTJJT", .hand_type = HandType.two_pair }, .bid = 220 };
    const r = Bid{ .hand = Hand{ .cards = "QQQJA", .hand_type = HandType.three_of_a_kind }, .bid = 483 };

    try std.testing.expectEqual(Bid.lessThan(CARDS, l, r), true);
    try std.testing.expectEqual(Bid.lessThan(CARDS, r, l), false);
    try std.testing.expectEqual(Bid.lessThan(CARDS, one, other), true);
    try std.testing.expectEqual(Bid.lessThan(CARDS, other, one), false);
    try std.testing.expectEqual(Bid.lessThan(CARDS, other, pair), false);
    try std.testing.expectEqual(Bid.lessThan(CARDS, pair, other), true);
}

test "bid less than part2" {
    const one: Bid =
        .{
        .hand = .{
            .cards = "T55J5",
            .hand_type = .full_house,
            .jokers = 1,
        },
        .bid = 684,
    };

    const other: Bid =
        .{
        .hand = .{
            .cards = "QQQJA",
            .hand_type = .four_of_a_kind,
            .jokers = 1,
        },
        .bid = 483,
    };
    const pair: Bid =
        .{
        .hand = .{
            .cards = "QQJA3",
            .hand_type = .three_of_a_kind,
            .jokers = 1,
        },
        .bid = 483,
    };

    const l = Bid{
        .hand = Hand{
            .cards = "KTJJT",
            .hand_type = .four_of_a_kind,
            .jokers = 2,
        },
        .bid = 220,
    };

    const r = Bid{
        .hand = Hand{
            .cards = "QQQJA",
            .hand_type = .four_of_a_kind,
            .jokers = 1,
        },
        .bid = 483,
    };

    try std.testing.expectEqual(Bid.lessThan(CARDS_PART2, l, r), false);
    try std.testing.expectEqual(Bid.lessThan(CARDS_PART2, r, l), true);
    try std.testing.expectEqual(Bid.lessThan(CARDS_PART2, one, other), true);
    try std.testing.expectEqual(Bid.lessThan(CARDS_PART2, other, one), false);
    try std.testing.expectEqual(Bid.lessThan(CARDS_PART2, other, pair), false);
    try std.testing.expectEqual(Bid.lessThan(CARDS_PART2, pair, other), true);
}

test "day7 input" {
    const ally = std.testing.allocator;
    const file = try std.fs.cwd().openFile("inputs/day7.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
    defer ally.free(lines);

    var bids_l = try decodeLines(ally, lines, Hand.init);
    defer bids_l.deinit();

    const bids = Bids.init(bids_l);

    const expected: u64 = 248422077;
    try std.testing.expectEqual(expected, bids.winnings());
}

test "day7 part 2 calibration" {
    const ally = std.testing.allocator;
    const lines =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;

    var bids_l = try decodeLines(ally, lines, Hand.init2);
    defer bids_l.deinit();

    const bids = Bids.init2(bids_l);

    const h1 = Hand.init2("32T3K");
    try std.testing.expectEqual(h1.jokers, 0);
    try std.testing.expectEqual(h1.hand_type, .one_pair);
    const h2 = Hand.init2("KTJJT");
    try std.testing.expectEqual(h2.jokers, 2);
    try std.testing.expectEqual(h2.hand_type, .four_of_a_kind);

    const expected_ranks = &[_]Bid{
        .{
            .hand = .{
                .cards = "32T3K",
                .hand_type = .one_pair,
            },
            .bid = 765,
        },
        .{
            .hand = .{
                .cards = "KK677",
                .hand_type = .two_pair,
            },
            .bid = 28,
        },
        .{
            .hand = .{
                .cards = "T55J5",
                .hand_type = .four_of_a_kind,
                .jokers = 1,
            },
            .bid = 684,
        },
        .{
            .hand = .{
                .cards = "QQQJA",
                .hand_type = .four_of_a_kind,
                .jokers = 1,
            },
            .bid = 483,
        },
        .{
            .hand = .{
                .cards = "KTJJT",
                .hand_type = .four_of_a_kind,
                .jokers = 2,
            },
            .bid = 220,
        },
    };
    try std.testing.expectEqualDeep(expected_ranks, bids.bids.items[0..5]);

    const expected: u64 = 5905;
    try std.testing.expectEqualDeep(expected, bids.winnings());
}

test "day7 input part2" {
    const ally = std.testing.allocator;
    const file = try std.fs.cwd().openFile("inputs/day7.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
    defer ally.free(lines);

    var bids_l = try decodeLines(ally, lines, Hand.init2);
    defer bids_l.deinit();

    const bids = Bids.init2(bids_l);

    const expected: u64 = 249817836;
    try std.testing.expectEqual(expected, bids.winnings());
}
