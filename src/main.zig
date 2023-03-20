const std = @import("std");

pub const BitlistErr = error{ OutOfRange, DifferentLengths };

pub const Bitlist = struct {
    const This = @This();
    // wordSize configures how many bits are there in a single
    // element of bitlist array
    const word_size: u64 = 64;
    // wordSizeLog2 allows optimized division by wordSize using
    // right shift (numBits >> wordSizeLog2)
    // Note: log_2(64) = 6
    const word_size_log2: u64 = 6;
    // bytesInWord defines how many bytes are there in a single
    // word i.e. wordSize/8
    const bytes_per_word: u64 = 8;
    // bytesInWordLog2 = log_2(8)
    const bytes_per_word_log2: u64 = 3;

    size: u64,
    data: []u64,
    ac: std.mem.Allocator,

    pub fn init(n: u64, ac: std.mem.Allocator) !Bitlist {
        var data: []u64 = try ac.alloc(u64, numWordsRequired(n));
        return This{
            .size = n,
            .ac = ac,
            .data = data,
        };
    }
    pub fn free(self: This) void {
        return self.ac.free(self.data);
    }
    // Gets the bit at the specified index
    pub fn bitAt(self: This, comptime idx: usize) bool {
        if (idx >= self.size) {
            return false;
        }
        const bit: usize = 1 << (idx % word_size);
        return self.data[idx >> word_size_log2] & bit == bit;
    }
    // Sets a bit to a specified value at an index
    pub fn setBitAt(self: This, comptime idx: usize, value: bool) BitlistErr!void {
        if (idx >= self.size) {
            return BitlistErr.OutOfRange;
        }
        const bit: usize = 1 << (idx % word_size);
        if (value) {
            self.data[idx >> word_size_log2] |= bit;
        } else {
            self.data[idx >> word_size_log2] ^= bit;
        }
    }
    // Number of set bits in the bitlist
    pub fn countOnes(self: This) u64 {
        var count: u64 = 0;
        var i: usize = 0;
        while (i < self.data.len) : (i += 1) {
            count += @popCount(self.data[i]);
        }
        return count;
    }
    // Checks if this bitlist contains another. That is,
    // the bitlist is a superset of the other bitlist.
    pub fn contains(self: This, other: This) BitlistErr!bool {
        if (self.size != other.size) {
            return BitlistErr.DifferentLengths;
        }
        var i: usize = 0;
        for (self.data) |word| {
            if (word ^ (word | other.data[i]) != 0) {
                return false;
            }
            i += 1;
        }
        return true;
    }
    // TODO: Leverage const vs. var? Use pointers?
    pub fn not_with_clone(self: This) !Bitlist {
        if (self.size == 0) {
            return self;
        }
        var ret = try self.clone();
        self.not(ret);
        return ret;
    }
    pub fn not(self: This, other: This) void {
        if (self.size == 0) {
            return;
        }
        var i: usize = 0;
        for (self.data) |word| {
            other.data[i] ^= word;
        }
    }
    pub fn clone(self: This) !Bitlist {
        var new_list: Bitlist = try Bitlist.init(self.size, self.ac);
        std.mem.copy(u64, new_list.data, self.data);
        return new_list;
    }
    // Num words required to hold a bitlist of N bits
    fn numWordsRequired(n: u64) usize {
        return (n + (word_size - 1)) >> word_size_log2;
    }
};

test "Bitlist" {
    var want: u64 = 256;
    const bl = try Bitlist.init(want, std.testing.allocator);
    defer bl.free();

    // Test initiation
    try std.testing.expectEqual(want, bl.size);
    want = 4;
    try std.testing.expectEqual(want, bl.data.len);

    // Counting ones.
    var wantOnes: u64 = 128;
    try std.testing.expectEqual(wantOnes, bl.countOnes());

    // Toggling bits at indices.
    try std.testing.expectEqual(false, bl.bitAt(10));
    try bl.setBitAt(10, true);
    try std.testing.expectEqual(true, bl.bitAt(10));
    try bl.setBitAt(10, false);
    try std.testing.expectEqual(false, bl.bitAt(10));

    // Clone.
    var cloned = try bl.clone();
    defer cloned.free();
    try cloned.setBitAt(10, true);
    try std.testing.expectEqual(true, cloned.bitAt(10));
    // Expect the original did not change as we made a copy.
    try std.testing.expectEqual(false, bl.bitAt(10));
}

test "Secondary" {
    var want: u64 = 256;
    const bl = try Bitlist.init(want, std.testing.allocator);
    defer bl.free();

    // Test initiation
    try std.testing.expectEqual(want, bl.size);
    want = 4;
    try std.testing.expectEqual(want, bl.data.len);

    // Counting ones.
    var wantOnes: u64 = 128;
    try std.testing.expectEqual(wantOnes, bl.countOnes());

    // Toggling bits at indices.
    try std.testing.expectEqual(false, bl.bitAt(10));
    try bl.setBitAt(10, true);
    try std.testing.expectEqual(true, bl.bitAt(10));
    try bl.setBitAt(10, false);
    try std.testing.expectEqual(false, bl.bitAt(10));
}

pub fn Queue(comptime Child: type) type {
    return struct {
        const This = @This();
        const Node = struct {
            data: Child,
            next: ?*Node,
        };
        gpa: std.mem.Allocator,
        start: ?*Node,
        end: ?*Node,

        pub fn init(gpa: std.mem.Allocator) This {
            return This{
                .gpa = gpa,
                .start = null,
                .end = null,
            };
        }
        pub fn enqueue(this: *This, value: Child) !void {
            const node = try this.gpa.create(Node);
            node.* = .{ .data = value, .next = null };
            if (this.end) |end| end.next = node //
            else this.start = node;
            this.end = node;
        }
        pub fn dequeue(this: *This) ?Child {
            const start = this.start orelse return null;
            defer this.gpa.destroy(start);
            if (start.next) |next|
                this.start = next
            else {
                this.start = null;
                this.end = null;
            }
            return start.data;
        }
    };
}

test "queue" {
    var int_queue = Queue(i32).init(std.testing.allocator);

    try int_queue.enqueue(25);
    try int_queue.enqueue(50);
    try int_queue.enqueue(75);
    try int_queue.enqueue(100);

    try std.testing.expectEqual(int_queue.dequeue(), 25);
    try std.testing.expectEqual(int_queue.dequeue(), 50);
    try std.testing.expectEqual(int_queue.dequeue(), 75);
    try std.testing.expectEqual(int_queue.dequeue(), 100);
    try std.testing.expectEqual(int_queue.dequeue(), null);

    try int_queue.enqueue(5);
    try std.testing.expectEqual(int_queue.dequeue(), 5);
    try std.testing.expectEqual(int_queue.dequeue(), null);
}
