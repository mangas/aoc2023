const std = @import("std");

const Map = struct {
    directions: []const u8,
    node_map: NodeMap,

    pub fn walk(self: *Map) u64 {
        var node: *Node = self.node_map.getPtr("AAA").?;

        var count: u64 = 0;
        while (!std.mem.eql(u8, node.*.id, "ZZZ")) : (count += 1) {
            const next = switch (self.directions[count % self.directions.len]) {
                'R' => node.right,
                'L' => node.left,
                else => unreachable,
            };
            node = self.node_map.getPtr(next).?;
        }

        return count;
    }

    fn walkFrom(self: *Map, from: *Node) !u64 {
        var node: *Node = from;

        var count: u64 = 0;
        while (!std.mem.endsWith(u8, node.id, "Z")) : (count += 1) {
            const next = switch (self.directions[count % self.directions.len]) {
                'R' => node.right,
                'L' => node.left,
                else => unreachable,
            };
            node = self.node_map.getPtr(next).?;
        }

        return count;
    }

    fn walk2(self: *Map) !u64 {
        var it = self.node_map.iterator();

        var count: u64 = 1;
        while (it.next()) |n| {
            if (!std.mem.endsWith(u8, n.key_ptr.*, "A")) continue;
            const steps = try self.walkFrom(n.value_ptr);
            count = (steps / std.math.gcd(count, steps)) * count;
        }

        return count;
    }

    pub fn deinit(self: *Map) void {
        self.node_map.deinit();
    }
};

const NodeMap = std.StringHashMap(Node);

const NodeId = []const u8;

const Node = struct {
    const Self = @This();
    id: NodeId,

    left: NodeId,
    right: NodeId,
};

fn decodeLines(
    ally: std.mem.Allocator,
    lines: []const u8,
) !Map {
    var it = std.mem.splitSequence(u8, lines, "\n");

    const directions = it.next().?;
    _ = it.next();

    var res: NodeMap = NodeMap.init(ally);
    while (it.next()) |line| {
        if (line.len == 0) continue;

        const node_id = line[0..3];
        const left_id = line[7..10];
        const right_id = line[12..15];

        const node = .{
            .id = node_id,
            .right = right_id,
            .left = left_id,
        };
        _ = try res.getOrPutValue(node_id, node);
    }

    return .{
        .directions = directions,
        .node_map = res,
    };
}

test "day 8 calibration steps" {
    const ally = std.testing.allocator;
    const lines =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    var map = try decodeLines(ally, lines);
    defer map.deinit();

    const expected: u64 = 2;
    try std.testing.expectEqualDeep(expected, map.walk());
}

test "day 8 input part 1" {
    const ally = std.testing.allocator;
    const file = try std.fs.cwd().openFile("inputs/day8.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
    defer ally.free(lines);

    var map = try decodeLines(ally, lines);
    defer map.deinit();

    const expected: u64 = 18673;
    try std.testing.expectEqualDeep(expected, map.walk());
}

test "day 8 calibration part 2" {
    const ally = std.testing.allocator;
    const lines =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
    ;

    var map = try decodeLines(ally, lines);
    defer map.deinit();

    const expected: u64 = 6;
    try std.testing.expectEqualDeep(expected, try map.walk2());
}

test "day 8 input part 2" {
    const ally = std.testing.allocator;
    const file = try std.fs.cwd().openFile("inputs/day8.txt", .{});
    defer file.close();
    const lines = try file.reader().readAllAlloc(ally, std.math.maxInt(u32));
    defer ally.free(lines);

    var map = try decodeLines(ally, lines);
    defer map.deinit();

    const expected: u64 = 17972669116327;
    try std.testing.expectEqualDeep(expected, try map.walk2());
}
