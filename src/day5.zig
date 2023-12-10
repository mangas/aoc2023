const std = @import("std");

const MAP_CATEGORIES: [8][]const u8 = .{ "seed", "soil", "fertilizer", "water", "light", "temperature", "humidity", "location" };

const Range = struct {
    const Self = @This();

    dest: u64,
    source: u64,
    size: u64,

    pub fn destination(self: *const Self, s: u64) ?u64 {
        if (s >= self.source and s <= self.source + self.size)
            return self.dest + s - self.source;

        return null;
    }

    pub fn source(self: *Self, dest: u64) ?u64 {
        if (dest >= dest and dest <= self.dest)
            return self.source + self.size;

        return null;
    }
};

const Seeds = std.ArrayList(u64);

const Map = struct {
    const Self = @This();

    seeds: Seeds,
    maps: *RangeMap,

    pub fn init(seeds: Seeds, maps: RangeMap) Self {
        return .{
            .seeds = seeds,
            .maps = maps,
        };
    }

    pub fn deinit(self: *Self) void {
        var rm: *RangeMap = self.maps;
        self.seeds.deinit();
        while (true) {
            const next = rm.next;
            rm.deinit();
            if (next == null) return;
            rm = next.?;
        }
    }

    pub fn lowestLocation(self: *const Self) !u64 {
        var rm: ?*const RangeMap = self.maps;

        var vals = try self.seeds.clone();
        defer vals.deinit();
        while (rm != null) : (rm = rm.?.next) {
            for (vals.items, 0..) |s, i| {
                vals.items[i] = rm.?.destination(s);
            }
        }

        return std.mem.min(u64, vals.items);
    }
};

const RangeList = std.ArrayList(Range);

const RangeMap = struct {
    const Self = @This();

    ally: std.mem.Allocator,
    next: ?*RangeMap = null,
    ranges: RangeList,

    pub fn init(ally: std.mem.Allocator, ranges: RangeList) !*Self {
        const s = try ally.create(Self);
        s.* = .{
            .ally = ally,
            .ranges = ranges,
        };

        return s;
    }

    pub fn deinit(self: *Self) void {
        self.ranges.deinit();
        const ally = self.ally;
        ally.destroy(self);
    }

    pub fn last(self: *Self) *Self {
        const n = self.next orelse return self;

        return n.last();
    }

    pub fn destination(self: *const Self, s: u64) u64 {
        for (self.ranges.items) |range| {
            if (range.destination(s)) |d| {
                return d;
            }
        }
        return s;
    }

    pub fn source(self: *Self, d: u64) u64 {
        for (self.ranges.items) |range| {
            if (range.source(d)) |s| {
                return s;
            }
        }
        return d;
    }
};

fn parseNumbers(line: []const u8) !Range {
    var r: [3]u64 = [_]u64{0} ** 3;
    var it = std.mem.splitSequence(u8, line, " ");
    var i: u8 = 0;
    while (it.next()) |number| {
        if (number.len == 0) continue;
        r[i] = try std.fmt.parseInt(u64, number, 10);
        i += 1;
    }

    return .{
        .dest = r[0],
        .source = r[1],
        .size = r[2],
    };
}

fn decodeLines(
    ally: std.mem.Allocator,
    line: []const u8,
) !Map {
    var lines_it = std.mem.splitSequence(u8, line, "\n");
    var seeds_it = std.mem.splitSequence(u8, lines_it.next().?["seeds: ".len..], " ");

    var seeds = Seeds.init(ally);

    while (seeds_it.next()) |seed_n| {
        try seeds.append(try std.fmt.parseInt(u64, seed_n, 10));
    }

    var res: ?Map = null;
    //empty
    _ = lines_it.next();

    // only seven transitions
    for (MAP_CATEGORIES[0..7]) |cat| {
        if (!std.mem.startsWith(u8, lines_it.next().?, cat)) {
            unreachable;
        }

        var ranges = RangeList.init(ally);
        while (lines_it.next()) |map_line| {
            if (map_line.len == 0) break;
            try ranges.append(try parseNumbers(map_line));
        }

        const m = try RangeMap.init(ally, ranges);
        if (res) |*r| {
            const latest = r.maps.last();
            latest.*.next = m;
        } else {
            res = .{ .seeds = seeds, .maps = m };
        }
    }

    return res.?;
}

fn calibrationValue(ally: std.mem.Allocator, lines: []const u8) u64 {
    const result = try decodeLines(ally, lines);

    const expected: u64 = 35;
    try std.testing.expectEqual(expected, result);
}

test "day5 calibration" {
    const ally = std.testing.allocator;
    const lines =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;
    // const map = try decodeLines(ally, lines);
    var map = try decodeLines(ally, lines);
    defer map.deinit();

    var humidity_ranges: RangeMap = .{
        .next = null,
        .ally = ally,
        .ranges = RangeList.fromOwnedSlice(ally, @constCast(&[_]Range{
            .{ .dest = 60, .source = 56, .size = 37 },
            .{ .dest = 56, .source = 93, .size = 4 },
        })),
    };
    var temperature_ranges: RangeMap = .{
        .next = &humidity_ranges,
        .ally = ally,
        .ranges = RangeList.fromOwnedSlice(ally, @constCast(&[_]Range{
            .{ .dest = 0, .source = 69, .size = 1 },
            .{ .dest = 1, .source = 0, .size = 69 },
        })),
    };
    var light_ranges: RangeMap = .{
        .next = &temperature_ranges,
        .ally = ally,
        .ranges = RangeList.fromOwnedSlice(ally, @constCast(&[_]Range{
            .{ .dest = 45, .source = 77, .size = 23 },
            .{ .dest = 81, .source = 45, .size = 19 },
            .{ .dest = 68, .source = 64, .size = 13 },
        })),
    };
    var water_ranges: RangeMap = .{
        .next = &light_ranges,
        .ally = ally,
        .ranges = RangeList.fromOwnedSlice(ally, @constCast(&[_]Range{
            .{ .dest = 88, .source = 18, .size = 7 },
            .{ .dest = 18, .source = 25, .size = 70 },
        })),
    };
    var fertilizer_ranges: RangeMap = .{
        .next = &water_ranges,
        .ally = ally,
        .ranges = RangeList.fromOwnedSlice(ally, @constCast(&[_]Range{
            .{ .dest = 49, .source = 53, .size = 8 },
            .{ .dest = 0, .source = 11, .size = 42 },
            .{ .dest = 42, .source = 0, .size = 7 },
            .{ .dest = 57, .source = 7, .size = 4 },
        })),
    };
    var soil_ranges: RangeMap = .{
        .next = &fertilizer_ranges,
        .ally = ally,
        .ranges = RangeList.fromOwnedSlice(ally, @constCast(&[_]Range{
            .{ .dest = 0, .source = 15, .size = 37 },
            .{ .dest = 37, .source = 52, .size = 2 },
            .{ .dest = 39, .source = 0, .size = 15 },
        })),
    };
    var seed_ranges: RangeMap = .{
        .next = &soil_ranges,
        .ally = ally,
        .ranges = RangeList.fromOwnedSlice(ally, @constCast(&[_]Range{
            .{ .dest = 50, .source = 98, .size = 2 },
            .{ .dest = 52, .source = 50, .size = 48 },
        })),
    };

    const expected: Map = .{
        .seeds = Seeds.fromOwnedSlice(ally, @constCast(&[_]u64{ 79, 14, 55, 13 })),
        .maps = &seed_ranges,
    };

    var em: *RangeMap = expected.maps;
    var rm: *RangeMap = map.maps;
    for (MAP_CATEGORIES[0..7]) |cat| {
        // std.debug.print("cat: {s}\n\n", .{cat});
        try std.testing.expectEqualSlices(Range, em.ranges.items, rm.ranges.items);
        if (std.mem.eql(u8, "humidity", cat)) continue;
        em = em.next.?;
        rm = rm.next.?;
    }
    try std.testing.expect(em.next == null);
    try std.testing.expect(rm.next == null);

    const expected_loc: u64 = 35;
    try std.testing.expectEqual(expected_loc, try map.lowestLocation());
}

test "day 5 puzzle " {
    const ally = std.testing.allocator;
    const file = try std.fs.cwd().openFile("inputs/day5.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
    defer ally.free(lines);

    var map = try decodeLines(ally, lines);
    defer map.deinit();

    const expected_loc: u64 = 510109797;
    try std.testing.expectEqual(expected_loc, try map.lowestLocation());
}
