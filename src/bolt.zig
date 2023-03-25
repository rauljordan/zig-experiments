const std = @import("std");

test "DB" {
    const db = try DB.open("testing.db", Config.default(), std.testing.allocator);
    _ = db;
}

const Page = struct { id: usize, flags: u16, count: u16, overflow: u32, ptr: *usize };
const Meta = struct {
    magic: u32,
    version: u32,
    page_size: u32,
    flags: u32,
    //root:
    freelist: usize,
    id: usize,
    //txid:
    checksum: u64,
};

pub const DB = struct {
    const This = @This();
    cfg: Config,
    file: std.fs.File,
    ac: std.mem.Allocator,
    mmapLock: std.Thread.Mutex,
    meta: Meta,
    pub fn open(path: *const [10:0]u8, cfg: Config, alloc: std.mem.Allocator) !This {
        // flock the file to prevent other processes from accessing it.
        var f = try std.fs.cwd().createFile(path, .{});
        try f.lock(std.fs.File.Lock.Exclusive);
        var db: This = .{
            .file = f,
            .cfg = cfg,
            .ac = alloc,
            .mmapLock = std.Thread.Mutex{},
        };
        try db.init(f);
        try db.mmap(f);
        return db;
    }
    pub fn init(self: This, f: std.fs.File) !void {
        _ = f;
        var buf = try self.ac.alloc(u8, std.mem.page_size * 4);
        defer self.ac.free(buf);

        var i: usize = 0;
        while (i < 2) : (i += 1) {
            var page = .Page{
                .id = i,
            };
            _ = page;
        }

        // Freelist at page 3

        // Empty leaf page at page 4

        // Write the buffer to the data file
        // Sync the data file
    }
    pub fn mmap(self: This, f: std.fs.File) !void {
        _ = f;
        self.mmapLock.lock();
        defer self.mmapLock.unlock();
        //std.os.mmap(ptr: ?[*]align(mem.page_size)u8, length: usize, prot: u32, flags: u32, fd: fd_t, offset: u64)
    }
};

pub const Config = struct {
    alloc_size: u64,
    max_batch_delay: u64,
    max_batch_size: u64,
    pub fn default() Config {
        return .{
            .alloc_size = 10,
            .max_batch_delay = 10,
            .max_batch_size = 10,
        };
    }
};
