const std = @import("std");

const Position = struct {
    const Self = @This();

    line: usize,
    start: usize,
    end: usize,

    pub fn len(self: *Self) usize {
        self.end - self.start + 1;
    }

    pub fn boundaryStart(self: *const Self) usize {
        if (self.start == 0) {
            return 0;
        }

        return self.start - 1;
    }

    pub fn isNeighbourNumber(self: *const Self, token: *const Token) bool {
        token.isNeighbourSymbol(self);
    }

    pub fn isNeighbourSymbol(self: *const Self, symbol: *const Token) bool {
        if (!symbol.isSymbol()) return false;

        const pos = symbol.position() orelse unreachable;

        return self.boundaryStart() == pos.start or self.end + 1 == pos.start;
    }

    pub fn hasAdjacentSymbol(self: *const Self, list: *const TokenList) bool {
        for (list.*.items) |token| {
            const symbol_pos = token.position() orelse return false;

            // Past relevant section
            if (!token.isSymbol() and symbol_pos.start > self.end + 1) {
                return false;
            }

            if (!token.isSymbol()) {
                continue;
            }

            // Symbols are len 1 so start == end
            if (symbol_pos.start >= self.boundaryStart() and symbol_pos.start <= self.end + 1) {
                return true;
            }
        }

        return false;
    }
};

const TokenTag = enum { none, symbol, number, gear };
const Gear =
    struct {
    const Self = @This();
    pos: Position,
    vertices: [2]u64 = [_]u64{0} ** 2,
    count: u8 = 0,

    pub fn ratio(self: *const Self) u64 {
        if (self.count != 2) return 0;
        return self.vertices[0] * self.vertices[1];
    }

    pub fn addVertice(self: *Self, n: u64) void {
        if (n == 0) return;
        self.*.count += 1;
        if (self.count > 2) return;
        self.vertices[self.count - 1] = n;
    }
};

const Token = union(TokenTag) {
    const Self = @This();

    none,
    symbol: Position,
    number: struct {
        pos: Position,
        value: ?u64 = null,
        processed: bool = false,
    },
    gear: Gear,

    pub fn asGear(self: *Self) ?*Gear {
        return switch (self.*) {
            Token.gear => |*g| g,
            else => null,
        };
    }

    pub fn isGear(self: *Self) bool {
        return switch (self.*) {
            Token.gear => true,
            else => false,
        };
    }

    pub fn mark(self: *Self) void {
        switch (self.*) {
            Token.number => |*s| s.*.processed = true,
            else => {},
        }
    }

    pub fn isSymbol(self: Self) bool {
        return switch (self) {
            TokenTag.symbol, TokenTag.gear => true,
            else => false,
        };
    }

    pub fn value(self: Self) u64 {
        return switch (self) {
            TokenTag.number => |n| if (!n.processed) n.value.? else 0,
            else => 0,
        };
    }

    pub fn position(self: Self) ?Position {
        return switch (self) {
            TokenTag.symbol => |p| p,
            TokenTag.number => |p| p.pos,
            TokenTag.gear => |p| p.pos,
            else => null,
        };
    }
};

const TokenList = std.ArrayList(Token);

fn checkNeighbours(list: TokenList) u64 {
    var sum: u64 = 0;

    for (list.items, 0..) |*p, i| {
        if (p.isSymbol()) continue;
        const before =
            i > 0 and p.position().?.isNeighbourSymbol(&list.items[i - 1]);

        const after = i < list.items.len - 1 and p.position().?.isNeighbourSymbol(&list.items[i + 1]);

        if (!before and !after) continue;

        sum += p.value();
        p.mark();
    }

    return sum;
}

fn collectRatios(current: ?TokenList, previous: ?TokenList) u64 {
    const prev = previous orelse return 0;

    var sum: u64 = 0;

    if (current) |list| {
        for (list.items, 0..) |*token, i| {
            var gear = token.asGear() orelse continue;

            for (prev.items) |prev_item| {
                const prev_pos = prev_item.position() orelse continue;
                if (prev_pos.start > gear.pos.end + 1) break;

                if (gear.pos.start >= prev_pos.boundaryStart() and gear.pos.end <= prev_pos.end + 1)
                    gear.addVertice(prev_item.value());
            }
            if (i > 0)
                gear.addVertice(list.items[i - 1].value());
            gear.addVertice(list.items[@min(list.items.len - 1, i + 1)].value());
        }
    }

    for (prev.items) |*token| {
        var gear = token.asGear() orelse continue;

        if (current) |list| {
            for (list.items) |item| {
                const pos = item.position() orelse continue;
                if (pos.start > gear.pos.end + 1) break;

                if (gear.pos.start >= pos.boundaryStart() and gear.pos.end <= pos.end + 1)
                    gear.addVertice(item.value());
            }
        }

        // std.debug.print("### \n\n {any} \n\n", .{gear});

        if (gear.count == 2) {
            sum += gear.ratio();
        }
    }

    return sum;
}

fn sumList(list: TokenList, previous: ?TokenList) u64 {
    var sum = checkNeighbours(list);

    const prev = previous orelse return sum;

    for (prev.items) |*p| {
        if (p.isSymbol()) continue;
        if (!p.position().?.hasAdjacentSymbol(&list)) continue;

        sum += p.value();
        p.mark();
    }

    for (list.items) |*p| {
        if (p.isSymbol()) continue;
        if (!p.position().?.hasAdjacentSymbol(&prev)) continue;

        sum += p.value();
        p.mark();
    }

    return sum;
}

fn calibrationValueExtended(ally: std.mem.Allocator, lines: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(ally);
    defer arena.deinit();
    var it = std.mem.splitSequence(u8, lines, "\n");

    var sum: u64 = 0;
    var i: u8 = 0;
    var previous: ?TokenList = null;
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const result = try decodeLine(arena.allocator(), line, i);
        const list_sum = collectRatios(result, previous);
        previous = result;

        i += 1;
        sum += list_sum;
    }

    return sum;
}

fn calibrationValue(ally: std.mem.Allocator, lines: []const u8) !u64 {
    var arena = std.heap.ArenaAllocator.init(ally);
    defer arena.deinit();
    var it = std.mem.splitSequence(u8, lines, "\n");

    var sum: u64 = 0;
    var i: u8 = 0;
    var previous: ?TokenList = null;
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }
        const result = try decodeLine(arena.allocator(), line, i);
        const list_sum = sumList(result, previous);
        previous = result;

        i += 1;
        sum += list_sum;
    }

    return sum;
}

fn addAndReset(line: []const u8, list: *TokenList, state: *Token, end: usize) !void {
    switch (state.*) {
        Token.symbol => |*s| {
            s.*.end = end;
        },
        Token.number => |*s| {
            s.*.pos.end = end;
            s.*.value = try std.fmt.parseInt(u64, line[s.*.pos.start .. s.*.pos.end + 1], 10);
        },
        Token.gear => {},
        else => unreachable,
    }
    const slot = try list.addOne();
    slot.* = state.*;
    state.* = Token.none;
}

fn decodeLine(ally: std.mem.Allocator, line: []const u8, n: usize) !TokenList {
    var res = TokenList.init(ally);
    var state: Token = Token.none;

    for (0..line.len) |i| {
        const c = line[i];

        switch (c) {
            '*' => {
                switch (state) {
                    .none => {},
                    Token.symbol, Token.number => {
                        try addAndReset(line, &res, &state, i - 1);
                    },
                    else => unreachable,
                }

                state = Token{ .gear = .{
                    .pos = .{
                        .line = n,
                        .start = i,
                        .end = i,
                    },
                } };
                try addAndReset(line, &res, &state, i);
            },
            '.' => {
                switch (state) {
                    .none => continue,
                    Token.symbol, Token.number => {
                        try addAndReset(line, &res, &state, i - 1);
                    },
                    else => unreachable,
                }
            },
            '0'...'9' => {
                switch (state) {
                    .none => {
                        state =
                            Token{ .number = .{ .pos = .{
                            .line = n,
                            .start = i,
                            .end = i,
                        } } };
                    },
                    .number => |*s| {
                        s.*.pos.end = i;
                    },
                    .symbol => {
                        try addAndReset(line, &res, &state, i - 1);
                        state = Token{ .number = .{ .pos = .{
                            .line = n,
                            .start = i,
                            .end = i,
                        } } };
                    },
                    else => unreachable,
                }
            },
            else => {
                switch (state) {
                    .none => {
                        state =
                            Token{ .symbol = .{
                            .line = n,
                            .start = i,
                            .end = i,
                        } };
                    },
                    .symbol => |*s| {
                        s.*.end = i;
                    },
                    .number => {
                        try addAndReset(line, &res, &state, i - 1);
                        state = Token{ .symbol = .{
                            .line = n,
                            .start = i,
                            .end = i,
                        } };
                    },
                    else => unreachable,
                }
            },
        }
    }
    switch (state) {
        .none => {},
        .symbol, .number => try addAndReset(line, &res, &state, line.len - 1),
        else => unreachable,
    }

    return res;
}

test "day3 calibration" {
    const lines =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    var it = std.mem.splitSequence(u8, lines, "\n");

    const expected =
        [_][]const Token{
        //467..114..
        &[_]Token{
            Token{ .number = .{
                .value = 467,
                .pos = .{
                    .start = 0,
                    .end = 2,
                    .line = 0,
                },
            } },
            Token{ .number = .{
                .value = 114,
                .pos = .{
                    .start = 5,
                    .end = 7,
                    .line = 0,
                },
            } },
        },
        //...*......
        &[_]Token{
            Token{
                .gear = .{
                    .pos = .{
                        .start = 3,
                        .end = 3,
                        .line = 1,
                    },
                },
            },
        },
        //..35..633.
        &[_]Token{
            Token{ .number = .{ .value = 35, .pos = .{
                .start = 2,
                .end = 3,
                .line = 2,
            } } },
            Token{ .number = .{ .value = 633, .pos = .{
                .start = 6,
                .end = 8,
                .line = 2,
            } } },
        },
        //......#...
        &[_]Token{
            Token{
                .symbol = .{
                    .start = 6,
                    .end = 6,
                    .line = 3,
                },
            },
        },
        //617*......
        &[_]Token{
            Token{ .number = .{ .value = 617, .pos = .{
                .start = 0,
                .end = 2,
                .line = 4,
            } } },
            Token{ .gear = .{
                .pos = .{
                    .start = 3,
                    .end = 3,
                    .line = 4,
                },
            } },
        },
        //.....+.58.
        &[_]Token{
            Token{ .symbol = .{
                .start = 5,
                .end = 5,
                .line = 5,
            } },
            Token{ .number = .{ .value = 58, .pos = .{
                .start = 7,
                .end = 8,
                .line = 5,
            } } },
        },
        //..592.....
        &[_]Token{
            Token{ .number = .{ .value = 592, .pos = .{
                .start = 2,
                .end = 4,
                .line = 6,
            } } },
        },
        //......755.
        &[_]Token{
            Token{ .number = .{ .value = 755, .pos = .{
                .start = 6,
                .end = 8,
                .line = 7,
            } } },
        },
        //...$.*....
        &[_]Token{
            Token{ .symbol = .{
                .start = 3,
                .end = 3,
                .line = 8,
            } },
            Token{ .gear = .{
                .pos = .{
                    .start = 5,
                    .end = 5,
                    .line = 8,
                },
            } },
        },
        //.664.598..
        &[_]Token{
            Token{ .number = .{ .value = 664, .pos = .{
                .start = 1,
                .end = 3,
                .line = 9,
            } } },
            Token{ .number = .{ .value = 598, .pos = .{
                .start = 5,
                .end = 7,
                .line = 9,
            } } },
        },
    };

    var i: u8 = 0;
    while (it.next()) |line| {
        var tokens = try decodeLine(std.testing.allocator, line, i);
        defer tokens.deinit();

        for (expected[i], 0..) |expected_tokens, t| {
            try std.testing.expectEqual(expected_tokens, tokens.items[t]);
        }
        i += 1;
    }

    const expected_sum: u64 = 4361;
    const sum: u64 = try calibrationValue(std.testing.allocator, lines);
    try std.testing.expectEqual(expected_sum, sum);
}

test "day3 puzzle" {
    const file = try std.fs.cwd().openFile("inputs/day3.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(u32));
    defer std.testing.allocator.free(lines);

    const expected_sum: u64 = 520019;
    const sum: u64 = try calibrationValue(std.testing.allocator, lines);
    try std.testing.expectEqual(expected_sum, sum);
}

test "day3 calibration extended" {
    const lines =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const expected: u64 = 467835;
    const sum: u64 = try calibrationValueExtended(std.testing.allocator, lines);
    try std.testing.expectEqual(expected, sum);
}

test "day3 puzzle extended" {
    const file = try std.fs.cwd().openFile("inputs/day3.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(std.testing.allocator, std.math.maxInt(u32));
    defer std.testing.allocator.free(lines);

    const expected_sum: u64 = 520019;
    const sum: u64 = try calibrationValueExtended(std.testing.allocator, lines);
    try std.testing.expectEqual(expected_sum, sum);
}
