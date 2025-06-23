const std = @import("std");
const net = std.net;
const print = std.debug.print;
const types = @import("types.zig");
const Router = @import("router.zig").Router;
const Request = types.Request;
const Response = types.Response;
const HttpMethod = types.HttpMethod;

pub const Server = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Server {
        return Server{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Server) void {
        _ = self;
    }

    pub fn listen(self: *Server, host: []const u8, port: u16, router: *Router) !void {
        const address = try net.Address.resolveIp(host, port);
        var server = try address.listen(.{});
        defer server.deinit();
        print("Server listening on http://{s}:{d}\n", .{ host, port });
        print("Available endpoints:\n", .{});
        print("   GET  /           - Welcome message\n", .{});
        print("   GET  /api/health - Health check\n", .{});
        print("   GET  /api/users  - Get all users\n", .{});
        print("   POST /api/users  - Create user\n", .{});
        print("   GET  /api/users/:id - Get user by ID\n", .{});
        print("   PUT  /api/users/:id - Update user\n", .{});
        print("   DELETE /api/users/:id - Delete user\n", .{});
        print("\n", .{});

        while (true) {
            const connection = server.accept() catch |err| {
                print("Error accepting connection: {}\n", .{err});
                continue;
            };

            // Handle the connection in a separate function
            self.handleConnection(connection, router) catch |err| {
                print("Error handling connection: {}\n", .{err});
            };
        }
    }

    fn handleConnection(self: *Server, connection: net.Server.Connection, router: *Router) !void {
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = try connection.stream.read(&buffer);

        if (bytes_read == 0) return;

        const request_data = buffer[0..bytes_read];

        // Parse HTTP request
        var req = try self.parseRequest(request_data);
        defer req.deinit();

        var res = Response.init(self.allocator);
        defer res.deinit();

        // Handle the request with router
        try router.handle(&req, &res);

        // Send response
        try self.sendResponse(connection.stream, &res);
    }

    fn parseRequest(self: *Server, data: []const u8) !Request {
        var req = Request.init(self.allocator);

        var lines = std.mem.splitSequence(u8, data, "\r\n");
        const first_line = lines.next() orelse return req;

        var parts = std.mem.splitSequence(u8, first_line, " ");
        const method_str = parts.next() orelse return req;
        const path_str = parts.next() orelse return req;

        // Parse method
        req.method = if (std.mem.eql(u8, method_str, "GET"))
            .GET
        else if (std.mem.eql(u8, method_str, "POST"))
            .POST
        else if (std.mem.eql(u8, method_str, "PUT"))
            .PUT
        else if (std.mem.eql(u8, method_str, "DELETE"))
            .DELETE
        else if (std.mem.eql(u8, method_str, "PATCH"))
            .PATCH
        else
            .GET;

        // Parse path and query parameters
        if (std.mem.indexOf(u8, path_str, "?")) |query_start| {
            req.path = path_str[0..query_start];
            const query_str = path_str[query_start + 1 ..];
            try self.parseQueryParams(&req, query_str);
        } else {
            req.path = path_str;
        }

        // Parse headers
        var in_body = false;
        var body_start: usize = 0;

        while (lines.next()) |line| {
            if (line.len == 0) {
                in_body = true;
                body_start = @intFromPtr(lines.rest().ptr) - @intFromPtr(data.ptr);
                break;
            }

            if (std.mem.indexOf(u8, line, ":")) |colon_pos| {
                const header_name = std.mem.trim(u8, line[0..colon_pos], " \t");
                const header_value = std.mem.trim(u8, line[colon_pos + 1 ..], " \t");
                try req.headers.put(header_name, header_value);
            }
        }

        // Parse body if present
        if (in_body and body_start < data.len) {
            req.body = data[body_start..];
        }

        return req;
    }

    fn parseQueryParams(self: *Server, req: *Request, query_str: []const u8) !void {
        _ = self;
        var params = std.mem.splitSequence(u8, query_str, "&");

        while (params.next()) |param| {
            if (std.mem.indexOf(u8, param, "=")) |eq_pos| {
                const key = param[0..eq_pos];
                const value = param[eq_pos + 1 ..];
                try req.query.put(key, value);
            }
        }
    }

    fn sendResponse(self: *Server, stream: net.Stream, res: *Response) !void {
        // Build response string
        var response = std.ArrayList(u8).init(self.allocator);
        defer response.deinit();

        // Status line
        try response.writer().print("HTTP/1.1 {} {s}\r\n", .{ @intFromEnum(res.status_code), @tagName(res.status_code) });

        // Headers
        var header_iterator = res.headers.iterator();
        while (header_iterator.next()) |entry| {
            try response.writer().print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        // Content-Length header
        if (res.body) |body| {
            try response.writer().print("Content-Length: {}\r\n", .{body.len});
        } else {
            try response.writer().print("Content-Length: 0\r\n", .{});
        }

        // End of headers
        try response.writer().print("\r\n", .{});

        // Body
        if (res.body) |body| {
            try response.writer().print("{s}", .{body});
        }

        // Send the complete response
        _ = try stream.writeAll(response.items);
    }
};
