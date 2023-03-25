const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc: std.mem.Allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var mutator = try Mutator.init(100, alloc);
    var items = try mutator.ac.alloc(u8, 10);
    defer mutator.ac.free(items);
    _ = mutator.mutate(10, &items);
}

pub const Strat = enum { Shrink, Expand };

pub const Mutator = struct {
    const This = @This();
    ac: std.mem.Allocator,
    input: []u8,
    max_size: usize,
    seed: u64,
    rng: *std.rand.Xoshiro256,
    accessed: bool,

    pub fn init(
        max_size: usize,
        ac: std.mem.Allocator,
        // TODO: Add customizable entropy source
    ) !This {
        var rand = std.rand.DefaultPrng.init(33);
        return .{
            .input = &.{},
            .max_size = max_size,
            .ac = ac,
            .seed = 1000,
            .rng = &rand,
            .accessed = false,
        };
    }

    pub fn mutate(self: This, times: usize, input: *[]u8) void {
        const strats: [2]Strat = [2]Strat{
            Strat.Shrink,
            Strat.Expand,
        };
        var i: usize = 0;
        while (i < times) : (i += 1) {
            const idx = self.rng.random().int(usize) % strats.len;
            const st = strats[idx];
            switch (st) {
                .Shrink => self.shrink(input),
                .Expand => self.expand(input),
            }
        }
    }

    pub fn deinit(self: This) void {
        _ = self;
    }

    pub fn rand_offset(self: This) usize {
        if (self.input.len == 0) {
            return 0;
        }
        return self.rng.random().int(usize) % self.input.len;
    }

    pub fn seed(self: *This, new_seed: u64) void {
        self.seed = new_seed ^ 0x12640367f4b7ea35;
    }

    fn shrink(self: This, data: *[]u8) void {
        if (data.len == 0) {
            return;
        }
        const offset = self.rand_offset();
        const to_remove = data.len - offset;
        _ = to_remove;
        std.debug.print("shrinking\n", .{});

        // Drain some bytes from the input.
    }

    fn expand(self: This, data: *[]u8) void {
        _ = data;
        _ = self;
        std.debug.print("expanding\n", .{});
    }

    fn bit(self: This, data: []u8) []u8 {
        _ = self;
        return data;
    }

    fn inc_byte(self: This, data: []u8) []u8 {
        _ = self;
        return data;
    }

    fn dec_byte(self: This, data: []u8) []u8 {
        _ = self;
        return data;
    }
};
