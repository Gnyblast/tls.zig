const std = @import("std");
const tls = @import("tls");
const cmn = @import("common.zig");

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    const sets = try readBadssl(gpa);
    defer sets.deinit();

    var ca_bundle = try cmn.initCaBundle(gpa);
    defer ca_bundle.deinit(gpa);

    for (sets.value) |set| {
        std.debug.print("\n{s}\n{s}\n", .{ set.heading, set.description });
        const fail = YesNo.parse(set.fail);
        const success = YesNo.parse(set.success);
        for (set.subdomains) |sd| {
            //std.debug.print("subdomain: {s}\n", .{sd.subdomain});

            var domain_buf: [128]u8 = undefined;
            const domain = try std.fmt.bufPrint(&domain_buf, "{s}.badssl.com", .{sd.subdomain});

            cmn.get(gpa, domain, if (sd.port == 0) null else sd.port, ca_bundle, false, false, .{}) catch |err| {
                std.debug.print(
                    "\t{s} {s} {}\n",
                    .{ fail.emoji(), domain, err },
                );
                std.debug.assert(fail != .no);
                continue;
            };
            std.debug.print("\t{s} {s}\n", .{ success.emoji(), domain });
            std.debug.assert(success != .no);
        }
    }
}

const YesNo = enum {
    yes,
    no,
    maybe,

    fn emoji(self: YesNo) []const u8 {
        return switch (self) {
            .yes => "✅",
            .no => "❌",
            .maybe => "🆗",
        };
    }

    fn parse(value: []const u8) YesNo {
        if (std.mem.eql(u8, value, "yes")) return .yes;
        if (std.mem.eql(u8, value, "no")) return .no;
        return .maybe;
    }
};

const BadsslSet = struct {
    heading: []const u8,
    description: []const u8,
    success: []const u8,
    fail: []const u8,
    subdomains: []struct {
        subdomain: []const u8,
        port: u16 = 0,
    },
};

// badssl.json is based on from https://badssl.com/dashboard/sets.js
// file used on https://badssl.com/dashboard/ browser test
fn readBadssl(gpa: std.mem.Allocator) !std.json.Parsed([]BadsslSet) {
    const data = @embedFile("badssl.json");
    return std.json.parseFromSlice([]BadsslSet, gpa, data, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    });
}
