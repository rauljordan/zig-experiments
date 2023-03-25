const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc: std.mem.Allocator = gpa.allocator();
    _ = alloc;
    defer _ = gpa.deinit();

    std.debug.print("Testing basic mutator", .{});
}

pub const Mutator = struct {
    const This = @This();
    ac: std.mem.Allocator,

    pub fn init(ac: std.mem.Allocator) !This {
        return .{
            .ac = ac,
        };
    }

    pub fn deinit(self: This) void {
        _ = self;
    }
};
