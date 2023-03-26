const std = @import("std");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var alloc: std.mem.Allocator = arena.allocator();
    defer _ = arena.deinit();

    const num_mutations = 100;
    std.debug.print("Running with arena allocator, 1M mutations\n", .{});
    try run_bench(alloc, num_mutations);
    //std.debug.print("\n", .{});

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // alloc = gpa.allocator();
    // defer _ = gpa.deinit();

    // std.debug.print("Running with general purpose allocator, 1M mutations\n", .{});
    // try run_bench(alloc, num_mutations);
}

fn run_bench(alloc: std.mem.Allocator, num_mutations: usize) !void {
    var mutator = try Mutator.init(100, alloc);
    defer mutator.deinit();
    var items = try mutator.ac.alloc(u8, 8);

    // 8 bytes.
    const initial = [8]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    std.mem.copy(u8, items, initial[0..8]);
    std.debug.print("input 0x{x}\n", .{
        std.fmt.fmtSliceHexLower(items),
    });

    mutator.input(items);

    var start = try std.time.Instant.now();
    try mutator.mutate(num_mutations);
    var end = try std.time.Instant.now();
    std.debug.print("output 0x{x}, took={}\n", .{
        std.fmt.fmtSliceHexLower(mutator.output()),
        std.fmt.fmtDuration(end.since(start)),
    });
}

pub const Strat = enum { Shrink, Expand, Bit, IncByte, DecByte, NegByte };

pub const Mutator = struct {
    const This = @This();
    ac: std.mem.Allocator,
    data: []u8,
    max_size: usize,
    seed: u64,
    rng: *std.rand.Xoshiro256,
    accessed: bool,

    pub fn init(
        max_size: usize,
        ac: std.mem.Allocator,
        // TODO: Add customizable entropy source
    ) !This {
        var rand = std.rand.DefaultPrng.init(1290192);
        return .{
            .data = &.{},
            .max_size = max_size,
            .ac = ac,
            .seed = 1000,
            .rng = &rand,
            .accessed = false,
        };
    }

    pub fn deinit(self: *This) void {
        self.ac.free(self.data);
    }

    pub fn input(self: *This, b: []u8) void {
        self.data = b;
    }

    pub fn output(self: This) []u8 {
        return self.data;
    }

    pub fn mutate(self: *This, times: usize) !void {
        const strats: [6]Strat = [6]Strat{
            Strat.Shrink,
            Strat.Expand,
            Strat.Bit,
            Strat.IncByte,
            Strat.DecByte,
            Strat.NegByte,
        };
        var i: usize = 0;
        while (i < times) : (i += 1) {
            const idx = self.rng.random().int(usize) % strats.len;
            const st = strats[idx];
            switch (st) {
                .Shrink => try self.shrink(),
                .Expand => try self.expand(),
                .Bit => try self.bit(),
                .IncByte => try self.inc_byte(),
                .DecByte => try self.dec_byte(),
                .NegByte => try self.neg_byte(),
            }
        }
    }

    pub fn rand_offset(self: This) usize {
        if (self.data.len == 0) {
            return 0;
        }
        return self.rng.random().int(usize) % self.data.len;
    }

    pub fn seed(self: *This, new_seed: u64) void {
        self.seed = new_seed ^ 0x12640367f4b7ea35;
    }

    fn shrink(self: *This) !void {
        if (self.data.len == 0) {
            return;
        }
        const offset = self.rand_offset();
        const can_remove = self.data.len - offset;

        var max_remove: usize = can_remove;
        if ((self.rng.random().int(usize) % 16) != 0) {
            max_remove = @min(16, can_remove);
        }
        const to_remove = self.rng.random().int(usize) % max_remove;

        // Drain the specified bytes from the input and put
        // the retained results into a smaller buffer.
        var smaller = try self.ac.alloc(u8, self.data.len - to_remove);
        var i: usize = 0;
        var j: usize = 0;
        while (i < self.data.len) : (i += 1) {
            if (i >= offset and i < offset + to_remove) {
                continue;
            } else {
                smaller[j] = self.data[i];
                j += 1;
            }
        }
        self.ac.free(self.data);
        self.input(smaller);
    }

    fn expand(self: *This) !void {
        if (self.data.len >= self.max_size) {
            return;
        }
        const offset = self.rand_offset();
        var max_expand = self.max_size - self.data.len;
        if ((self.rng.random().int(usize) % 16) != 0) {
            max_expand = @min(16, max_expand);
        }
        const to_expand = self.rng.random().int(usize) % max_expand;
        var expanded = try self.ac.alloc(u8, to_expand + self.data.len);
        std.mem.copy(u8, expanded[0..offset], self.data[0..offset]);
        std.mem.copy(
            u8,
            expanded[offset + to_expand .. expanded.len],
            self.data[offset..self.data.len],
        );
        self.ac.free(self.data);
        self.input(expanded);
    }

    fn bit(self: *This) !void {
        if (self.data.len == 0) {
            return;
        }
        const offset = self.rand_offset();
        const x = self.data[offset];
        const lhs: u8 = 1;
        const rhs: u3 = @truncate(u3, self.rng.random().int(usize) % 8);
        self.data[offset] = x ^ (lhs << rhs);
        return;
    }

    fn inc_byte(self: *This) !void {
        if (self.data.len == 0) {
            return;
        }
        const offset = self.rand_offset();
        const x = self.data[offset];
        self.data[offset] = (x + 1) % 7;
        return;
    }

    fn dec_byte(self: *This) !void {
        if (self.data.len == 0) {
            return;
        }
        const offset = self.rand_offset();
        const x = self.data[offset];
        self.data[offset] = (x + 1) % 7;
        return;
    }

    fn neg_byte(self: *This) !void {
        if (self.data.len == 0) {
            return;
        }
        const offset = self.rand_offset();
        const x = self.data[offset];
        self.data[offset] = x;
        return;
    }
};
