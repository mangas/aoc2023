const std = @import("std");

const Position = struct {
    line: usize,
    start: usize,
    end: usize,
};

const TokenTag = enum { skip, symbol, number };

const Token = union(TokenTag) {
    skip,
    symbol: Position,
    number: Position,
};

const TokenList = std.ArrayList(Token);

fn addAndReset(list: *TokenList, state: *Token, end: usize) !void {
    switch (state.*) {
        Token.symbol, Token.number => |*s| {
            s.*.end = end;
        },
        else => unreachable,
    }
    var slot = try list.addOne();
    slot.* = state.*;
    state.* = Token.skip;
}

fn decodeLine(ally: std.mem.Allocator, line: []const u8, n: usize) !TokenList {
    var res = TokenList.init(ally);
    var state: Token = Token.skip;

    for (0..line.len) |i| {
        const c = line[i];

        switch (c) {
            '.' => {
                switch (state) {
                    .skip => continue,
                    Token.number, Token.symbol => {
                        try addAndReset(&res, &state, i - 1);
                    },
                }
            },
            '0'...'9' => {
                switch (state) {
                    .skip => {
                        state =
                            Token{ .number = .{
                            .line = n,
                            .start = i,
                            .end = i,
                        } };
                    },
                    .number => |*s| {
                        s.*.end = i;
                    },
                    .symbol => {
                        try addAndReset(&res, &state, i - 1);
                        state = Token{ .number = .{
                            .line = n,
                            .start = i,
                            .end = i,
                        } };
                    },
                }
            },
            else => {
                switch (state) {
                    .skip => {
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
                        try addAndReset(&res, &state, i - 1);
                        state = Token{ .symbol = .{
                            .line = n,
                            .start = i,
                            .end = i,
                        } };
                    },
                }
            },
        }
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
                .start = 0,
                .end = 2,
                .line = 0,
            } },
            Token{ .number = .{
                .start = 5,
                .end = 7,
                .line = 0,
            } },
        },
        //...*......
        &[_]Token{
            Token{
                .symbol = .{
                    .start = 3,
                    .end = 3,
                    .line = 1,
                },
            },
        },
        //..35..633.
        &[_]Token{
            Token{ .number = .{
                .start = 2,
                .end = 3,
                .line = 2,
            } },
            Token{ .number = .{
                .start = 6,
                .end = 8,
                .line = 2,
            } },
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
            Token{ .number = .{
                .start = 0,
                .end = 2,
                .line = 4,
            } },
            Token{ .symbol = .{
                .start = 3,
                .end = 3,
                .line = 4,
            } },
        },
        //.....+.58.
        &[_]Token{
            Token{ .symbol = .{
                .start = 5,
                .end = 5,
                .line = 5,
            } },
            Token{ .number = .{
                .start = 7,
                .end = 8,
                .line = 5,
            } },
        },
        //..592.....
        &[_]Token{
            Token{ .number = .{
                .start = 2,
                .end = 4,
                .line = 6,
            } },
        },
        //......755.
        &[_]Token{
            Token{ .number = .{
                .start = 6,
                .end = 8,
                .line = 7,
            } },
        },
        //...$.*....
        &[_]Token{
            Token{ .symbol = .{
                .start = 3,
                .end = 3,
                .line = 8,
            } },
            Token{ .symbol = .{
                .start = 5,
                .end = 5,
                .line = 8,
            } },
        },
        //.664.598..
        &[_]Token{
            Token{ .number = .{
                .start = 1,
                .end = 3,
                .line = 9,
            } },
            Token{ .number = .{
                .start = 5,
                .end = 7,
                .line = 9,
            } },
        },
    };

    var i: u8 = 0;
    while (it.next()) |line| {
        var list = try decodeLine(std.testing.allocator, line, i);
        const tokens = try list.toOwnedSlice();
        defer std.testing.allocator.free(tokens);

        for (expected[i], 0..) |expected_tokens, t| {
            try std.testing.expectEqual(expected_tokens, tokens[t]);
        }
        i += 1;
    }
}
