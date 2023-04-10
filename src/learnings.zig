const std = @import("std");

const S = struct {
    tag: u8,
    data: u32,
};

/// MultiArrayList example with sorting included.
pub fn example() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const arena = arena_instance.allocator();

    var list: std.MultiArrayList(S) = .{};

    try list.append(arena, .{ .tag = 42, .data = 99999999 });
    try list.append(arena, .{ .tag = 10, .data = 1231011 });
    try list.append(arena, .{ .tag = 69, .data = 1337 });
    try list.append(arena, .{ .tag = 1, .data = 1 });

    const TagSort = struct {
        tags: []const u8,

        pub fn lessThan(ctx: @This(), lhs_index: usize, rhs_index: usize) bool {
            return ctx.tags[lhs_index] < ctx.tags[rhs_index];
        }
    };

    list.sort(TagSort{ .tags = list.items(.tag) });

    for (list.items(.tag), list.items(.data)) |tag, data| {
        std.debug.print("tag = {d}, data = {d}\n", .{ tag, data });
    }
}
