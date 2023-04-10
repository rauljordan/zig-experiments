const std = @import("std");
const int = std.math.big.int;

test "gpa(small_object)" {
    var impl = TurboPool(SmallObject).GPA.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(SmallObject, &impl, num_iters);
}

test "gpa(medium_object)" {
    var impl = TurboPool(MediumObject).GPA.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(MediumObject, &impl, num_iters);
}

test "gpa(big.int.Managed)" {
    var impl = TurboPool(int.Managed).GPA.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(int.Managed, &impl, num_iters);
}

test "arena(small_object)" {
    var impl = TurboPool(SmallObject).Arena.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(SmallObject, &impl, num_iters);
}

test "arena(medium_object)" {
    var impl = TurboPool(MediumObject).Arena.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(MediumObject, &impl, num_iters);
}

test "arena(big.int.Managed)" {
    var impl = TurboPool(int.Managed).Arena.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(int.Managed, &impl, num_iters);
}

test "turbopool(small_object)" {
    var impl = TurboPool(SmallObject).Pool.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(SmallObject, &impl, num_iters);
}

test "turbopool(medium_object)" {
    var impl = TurboPool(MediumObject).Pool.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(MediumObject, &impl, num_iters);
}

test "turbopool(big.int.Managed)" {
    var impl = TurboPool(int.Managed).Pool.init(std.testing.allocator);
    defer impl.deinit();

    const num_iters = 1_000_000;
    try runPerfTest(int.Managed, &impl, num_iters);
}

fn runPerfTest(
    comptime Object: type,
    pool: anytype,
    max_rounds: usize,
) !void {
    const start = try std.time.Instant.now();

    var slots = std.BoundedArray(*Object, 256){};
    var rounds: usize = max_rounds;

    var random_source = std.rand.DefaultPrng.init(1337);
    const rng = random_source.random();

    var max_fill_level: usize = 0;
    var allocs: usize = 0;
    var frees: usize = 0;

    while (rounds > 0) {
        rounds -= 1;
        const free_chance = @intToFloat(f32, slots.len) /
            @intToFloat(f32, slots.buffer.len - 1); // more elements => more frees
        const alloc_chance = 1.0 - free_chance; // more elements => less allocs

        if (slots.len > 0) {
            if (rng.float(f32) <= free_chance) {
                var index = rng.intRangeLessThan(usize, 0, slots.len);
                const ptr = slots.swapRemove(index);
                pool.delete(ptr);
                frees += 1;
            }
        }

        if (slots.len < slots.capacity()) {
            if (rng.float(f32) <= alloc_chance) {
                const item = try pool.new();
                slots.appendAssumeCapacity(item);
                allocs += 1;
            }
        }
        max_fill_level = std.math.max(max_fill_level, slots.len);
    }

    for (slots.slice()) |ptr| {
        pool.delete(ptr);
    }

    const end = try std.time.Instant.now();

    std.debug.print(
        "time={}, max_fill={d:>3}%, allocs={d:6}, frees={d:6}\n",
        .{
            std.fmt.fmtDuration(end.since(start)),
            100 * max_fill_level / slots.buffer.len,
            allocs,
            frees,
        },
    );
}

const SmallObject = struct {
    small: [1]u8,
};

const MediumObject = struct {
    medium: [8192]u8,
};

fn TurboPool(comptime T: type) type {
    return struct {
        pub const GPA = struct {
            allocator: std.mem.Allocator,

            pub fn init(allocator: std.mem.Allocator) @This() {
                return .{ .allocator = allocator };
            }

            pub fn new(self: @This()) !*T {
                return try self.allocator.create(T);
            }

            pub fn delete(self: @This(), obj: *T) void {
                self.allocator.destroy(obj);
            }

            pub fn deinit(self: *@This()) void {
                _ = self;
            }
        };
        const Arena = struct {
            arena: std.heap.ArenaAllocator,

            pub fn init(allocator: std.mem.Allocator) @This() {
                return .{ .arena = std.heap.ArenaAllocator.init(allocator) };
            }

            pub fn deinit(self: *@This()) void {
                self.arena.deinit();
            }

            pub fn new(self: *@This()) !*T {
                return try self.arena.allocator().create(T);
            }

            pub fn delete(self: *@This(), obj: *T) void {
                self.arena.allocator().destroy(obj);
            }
        };
        pub const Pool = struct {
            const List = std.TailQueue(T);
            arena: std.heap.ArenaAllocator,
            free: List = .{},

            pub fn init(allocator: std.mem.Allocator) Pool {
                return .{
                    .arena = std.heap.ArenaAllocator.init(allocator),
                };
            }
            pub fn deinit(self: *Pool) void {
                self.arena.deinit();
            }
            pub fn new(self: *Pool) !*T {
                const obj = if (self.free.popFirst()) |item|
                    item
                else
                    try self.arena.allocator().create(List.Node);
                return &obj.data;
            }
            pub fn delete(self: *Pool, obj: *T) void {
                const node = @fieldParentPtr(List.Node, "data", obj);
                self.free.append(node);
            }
        };
    };
}
