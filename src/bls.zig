const std = @import("std");

pub fn main() void {
    var item1 = Circle.init();
    var item2 = Circle.init();
    const shapes = [_]*Shape{
        &item1.shape,
        &item2.shape,
    };
    for (shapes) |shape| {
        shape.draw();
        shape.move();
    }
}

const testing = std.testing;

test "Something" {
    try testing.expect(true);
}

const Shape = struct {
    drawFn: *const fn (ptr: *Shape) void,
    moveFn: *const fn (ptr: *Shape) void,
    pub fn draw(self: *Shape) void {
        self.drawFn(self);
    }
    pub fn move(self: *Shape) void {
        self.moveFn(self);
    }
};

const Circle = struct {
    radius: i32,
    shape: Shape,
    pub fn init() Circle {
        const impl = struct {
            pub fn draw(ptr: *Shape) void {
                const self = @fieldParentPtr(Circle, "shape", ptr);
                self.draw();
            }
            pub fn move(ptr: *Shape) void {
                const self = @fieldParentPtr(Circle, "shape", ptr);
                self.move();
            }
        };
        return .{
            .radius = 0,
            .shape = .{ .moveFn = impl.move, .drawFn = impl.draw },
        };
    }
    pub fn move(self: *Circle) void {
        _ = self;
        std.debug.print("Moving", .{});
    }
    pub fn draw(self: *Circle) void {
        _ = self;
        std.debug.print("Drawing", .{});
    }
};
