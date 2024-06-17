const std = @import("std");
const tls = @import("tls");
const Certificate = std.crypto.Certificate;
const showStats = @import("common.zig").showStats;

// Start server from tls_server folder:
// $ cd tls_server && ./run.sh
// It will generate certificate and start Go server.
// After connecting server will stream a large text file.
pub fn main() !void {
    const gpa = std.heap.page_allocator;

    // Init certificate bundle with server certificate
    var ca_bundle: Certificate.Bundle = .{};
    defer ca_bundle.deinit(gpa);
    const dir = std.fs.cwd().openDir("../tls_server", .{ .iterate = true }) catch brk: {
        break :brk try std.fs.cwd().openDir("tls_server", .{ .iterate = true });
    };
    try ca_bundle.addCertsFromDir(gpa, dir);

    // Make tcp connection
    const host = "localhost";
    var tcp = try std.net.tcpConnectToHost(gpa, host, 8443);
    defer tcp.close();

    // Upgrade tcp connection to tls client
    var cli = tls.client(tcp);
    var stats: tls.Stats = .{};
    try cli.handshake(host, ca_bundle, .{ .stats = &stats });

    // Show response
    var n: usize = 0;
    while (try cli.next()) |data| {
        n += data.len;
        std.debug.print("{s}", .{data});
    }
    try cli.close();
    std.debug.print("{} bytes read\n", .{n});
    showStats(&stats, host);
}
