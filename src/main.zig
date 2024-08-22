const std = @import("std");
const builtin = @import("builtin");
const net = @import("std").net;
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    const host = [4]u8{ 127, 0, 0, 1 };
    const port = 3490;
    const addr = net.Address.initIp4(host, port);
    const socket = try std.posix.socket(addr.any.family, std.posix.SOCK.STREAM, std.posix.IPPROTO.TCP);
    _ = net.Stream{ .handle = socket };

    try stdout.print("Server Addr: {any}\n", .{addr});
    var server = try addr.listen(.{});
    while (true) {
        const connection = try server.accept();
        var buffer: [1000]u8 = undefined;
        for (0..buffer.len) |i| {
            buffer[i] = 0;
        }
        try read_request(connection, buffer[0..buffer.len]);
        const request = parse_request(buffer[0..buffer.len]);
        try stdout.print("Request: {any}\n", .{request});

        if (request.method == Method.GET) {
            try send_200(connection);
        }
    }
}

const Connection = std.net.Server.Connection;
fn read_request(conn: Connection, buffer: []u8) !void {
    const reader = conn.stream.reader();
    _ = try reader.read(buffer);
}

const Map = std.static_string_map.StaticStringMap;
const MethodMap = Map(Method).initComptime(.{
    .{ "GET", Method.GET },
});

pub const Method = enum {
    GET,
    pub fn init(text: []const u8) !Method {
        return MethodMap.get(text).?;
    }
    pub fn is_supported(m: []const u8) bool {
        const method = MethodMap.get(m);
        if (method) |_| {
            return true;
        }
        return false;
    }
};

const Request = struct {
    method: Method,
    version: []const u8,
    uri: []const u8,
    pub fn init(method: Method, uri: []const u8, version: []const u8) Request {
        return Request{
            .method = method,
            .uri = uri,
            .version = version,
        };
    }
};

pub fn parse_request(text: []u8) Request {
    const line_index = std.mem.indexOfScalar(u8, text, '\n') orelse text.len;
    var iterator = std.mem.splitScalar(u8, text[0..line_index], ' ');
    const method = try Method.init(iterator.next().?);
    const uri = iterator.next().?;
    const version = iterator.next().?;
    const request = Request.init(method, uri, version);
    return request;
}

fn send_200(conn: Connection) !void {
    const message = ("HTTP/1.1 200 OK\nContent-Length: 48" ++ "\nContent-Type: text/html\n" ++ "Connection: Closed\n\n<html><body>" ++ "<h1>Hello, World!</h1></body></html>");
    _ = try conn.stream.write(message);
}
