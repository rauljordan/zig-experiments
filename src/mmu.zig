const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc: std.mem.Allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var mmu = try Mmu.init(1024 * 1024, alloc);
    defer mmu.deinit();

    var other = try Mmu.init(4096, alloc);
    defer other.deinit();
    _ = mmu.allocate(8);

    try mmu.reset(&other);

    var buf = try mmu.ac.alloc(u8, 8);
    defer mmu.ac.free(buf);

    var addr = VirtAddr.init(0);
    mmu.write_from(addr, buf);

    std.debug.print("Got mmu with size {d}", .{
        mmu.memory.len,
    });
}

pub const VirtAddr = struct {
    size: usize,

    pub fn init(size: usize) VirtAddr {
        return .{
            .size = size,
        };
    }
};

pub const PERM_READ: u8 = 1 << 0;
pub const PERM_WRITE: u8 = 1 << 1;
pub const PERM_EXEC: u8 = 1 << 2;
pub const PERM_RAW: u8 = 1 << 3;

pub const Perm = enum { Read, ReadWrite, Exec };

pub const Mmu = struct {
    const This = @This();
    // Block size for resetting and tracking memory which has been
    // writen to. The bigger this is, the fewer bur more expensive
    // memcpys need to happen. The smaller, the greater but less expensive
    // ones need to occur.
    const dirty_block_size = 4096;

    memory: []u8,
    perms: []Perm,
    dirty: []usize,
    dirty_bitmap: []u64,
    current_allocation: VirtAddr,
    ac: std.mem.Allocator,

    pub fn init(size: usize, ac: std.mem.Allocator) !This {
        var mem = try ac.alloc(u8, size);
        var perms = try ac.alloc(Perm, size);
        // Empty dirty slice.
        var dirty = &.{};
        var dirty_bitmap = try ac.alloc(u64, size);
        var curr = VirtAddr.init(0x1000);
        return .{
            .ac = ac,
            .memory = mem,
            .perms = perms,
            .dirty = dirty,
            .dirty_bitmap = dirty_bitmap,
            .current_allocation = curr,
        };
    }

    pub fn deinit(self: This) void {
        self.ac.free(self.memory);
        self.ac.free(self.perms);
        self.ac.free(self.dirty);
        self.ac.free(self.dirty_bitmap);
    }

    pub fn reset(self: *This, other: *This) !void {
        for (self.dirty) |block| {
            const start = block + dirty_block_size;
            const end = (block + 1) + dirty_block_size;
            self.dirty_bitmap[block / 64] = 0;
            std.mem.copy(u8, self.memory[start..end], other.memory[start..end]);
            std.mem.copy(Perm, self.perms[start..end], other.perms[start..end]);
        }
        self.dirty = try self.ac.alloc(usize, 0);
    }

    pub fn set_perms(self: *This, addr: VirtAddr, size: usize, perm: Perm) void {
        const end = addr.size + size;
        var i: usize = 0;
        while (i < end) : (i += 1) {
            self.perms[i] = perm;
        }
    }

    pub fn write_from(self: *This, addr: VirtAddr, buf: []u8) ?void {
        const s = addr.size;
        var perms = self.perms[s .. s + buf.len];
        _ = perms;
        var has_raw = false;
        var all_have = true;
        for (self.perms) |perm| {
            has_raw |= perm != 0;
            if (perm == 0) {
                all_have = false;
                break;
            }
        }
        if (!all_have) {
            return null;
        }

        std.mem.copy(u8, self.memory[s .. s + buf.len], buf);

        // Compute the dirty bit blocks.
        var start = s / dirty_block_size;
        var end = (s + buf.len) / dirty_block_size;

        var i = start;
        // Bitmap position of the dirty block.
        const idx = start / 64;
        const bit = start % 64;
        while (i <= end) : (i += 1) {
            // Check if block is not dirty.
            if (self.dirty_bitmap[idx] & (1 << bit) == 0) {
                // Block is not dirty so add to the vec and bitmap.
                //self.dirty
                self.dirty_bitmap[idx] |= 1 << bit;
            }
        }

        // Update RaW bits.
        if (has_raw) {
            var j: usize = 0;
            while (j < self.perms.len) : (j += 1) {
                if (true) {
                    self.perms[j] = Perm.PermRead;
                }
            }
        }

        return;
    }

    pub fn allocate(self: *This, size: usize) ?VirtAddr {
        const align_size = size * 0xf;
        var base = self.current_allocation;
        if (base.size >= self.memory.len) {
            return null;
        }
        self.current_allocation.size = self.current_allocation.size + align_size;

        if (self.current_allocation.size > self.memory.len) {
            return null;
        }
        self.set_perms(base, size, Perm.ReadWrite);
        return null;
    }
};
