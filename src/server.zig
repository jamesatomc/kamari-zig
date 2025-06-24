const std = @import("std");
const net = std.net;
const print = std.debug.print;
const types = @import("types.zig");
const Router = @import("router.zig").Router;
const Request = types.Request;
const Response = types.Response;
const HttpMethod = types.HttpMethod;
const HttpStatus = types.HttpStatus;

// Server configuration
pub const ServerConfig = struct {
    max_connections: u32 = 100,
    buffer_size: usize = 8192,
    timeout_ms: u64 = 30000,
    enable_logging: bool = true,
    cors_enabled: bool = true,
    max_body_size: usize = 1024 * 1024, // 1MB
};

pub const ServerError = error{
    InvalidRequest,
    RequestTooLarge,
    Timeout,
    ConnectionClosed,
    NoRouterConfigured,
};

pub const Server = struct {
    allocator: std.mem.Allocator,
    config: ServerConfig,
    router: ?*Router,
    running: std.atomic.Value(bool),

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) Server {
        return Server{
            .allocator = allocator,
            .config = config,
            .router = null,
            .running = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *Server) void {
        self.stop();
    }

    pub fn setRouter(self: *Server, router: *Router) void {
        self.router = router;
    }

    pub fn stop(self: *Server) void {
        self.running.store(false, .monotonic);
    }

    pub fn listen(self: *Server, host: []const u8, port: u16) !void {
        if (self.router == null) {
            return ServerError.NoRouterConfigured;
        }

        const address = try net.Address.resolveIp(host, port);
        var server = try address.listen(.{});
        defer server.deinit();

        self.running.store(true, .monotonic);

        if (self.config.enable_logging) {
            self.logServerInfo(host, port);
        }

        while (self.running.load(.monotonic)) {
            const connection = server.accept() catch |err| switch (err) {
                error.WouldBlock => continue,
                else => {
                    if (self.config.enable_logging) {
                        print("Error accepting connection: {}\n", .{err});
                    }
                    continue;
                },
            };

            // Handle the connection
            self.handleConnection(connection) catch |err| {
                if (self.config.enable_logging) {
                    print("Error handling connection: {}\n", .{err});
                }
            };
        }
    }

    pub fn logServerInfo(self: *Server, host: []const u8, port: u16) void {
        const blue = "\x1b[34m";
        const green = "\x1b[32m";
        const yellow = "\x1b[33m";
        const cyan = "\x1b[36m";
        const reset = "\x1b[0m";
        const bold = "\x1b[1m";
        const red = "\x1b[31m";

        const box_width = 53;
        const separator = "+---------------------------------------------------+";

        print("\n{s}{s}{s}\n", .{ cyan, separator, reset });

        // Helper function to create properly padded lines
        const formatLine = struct {
            fn call(allocator: std.mem.Allocator, text: []const u8, width: usize, color_start: []const u8, color_end: []const u8, border_color: []const u8, reset_color: []const u8) !void {
                const visible_len = text.len;
                const available_space = width - 4; // Account for "| " and " |"

                if (visible_len >= available_space) {
                    print("{s}|{s} {s}{s}{s} {s}|{s}\n", .{ border_color, reset_color, color_start, text, color_end, border_color, reset_color });
                } else {
                    const padding_needed = available_space - visible_len;
                    const padding = try allocator.alloc(u8, padding_needed);
                    defer allocator.free(padding);
                    @memset(padding, ' ');

                    print("{s}|{s} {s}{s}{s}{s} {s}|{s}\n", .{ border_color, reset_color, color_start, text, color_end, padding, border_color, reset_color });
                }
            }
        }.call;

        formatLine(self.allocator, "[SERVER] Kamari-Zig Server Started", box_width, bold, reset, cyan, reset) catch {};
        print("{s}{s}{s}\n", .{ cyan, separator, reset });

        // URL line
        const url_text = std.fmt.allocPrint(self.allocator, "[URL] http://{s}:{d}", .{ host, port }) catch "[URL] Connection Info";
        defer if (!std.mem.eql(u8, url_text, "[URL] Connection Info")) self.allocator.free(url_text);
        formatLine(self.allocator, url_text, box_width, yellow, reset, cyan, reset) catch {};

        formatLine(self.allocator, "[CONFIG]", box_width, yellow, reset, cyan, reset) catch {};

        // Config lines
        const cors_status = if (self.config.cors_enabled) "Enabled" else "Disabled";
        const cors_color = if (self.config.cors_enabled) green else red;
        const cors_text = std.fmt.allocPrint(self.allocator, "  * CORS: {s}", .{cors_status}) catch "  * CORS: Unknown";
        defer if (!std.mem.eql(u8, cors_text, "  * CORS: Unknown")) self.allocator.free(cors_text);
        formatLine(self.allocator, cors_text, box_width, cors_color, reset, cyan, reset) catch {};

        const logging_status = if (self.config.enable_logging) "Enabled" else "Disabled";
        const logging_color = if (self.config.enable_logging) green else red;
        const logging_text = std.fmt.allocPrint(self.allocator, "  * Logging: {s}", .{logging_status}) catch "  * Logging: Unknown";
        defer if (!std.mem.eql(u8, logging_text, "  * Logging: Unknown")) self.allocator.free(logging_text);
        formatLine(self.allocator, logging_text, box_width, logging_color, reset, cyan, reset) catch {};

        const body_size_text = std.fmt.allocPrint(self.allocator, "  * Max Body Size: {d} MB", .{self.config.max_body_size / 1024 / 1024}) catch "  * Max Body Size: 1 MB";
        defer if (!std.mem.eql(u8, body_size_text, "  * Max Body Size: 1 MB")) self.allocator.free(body_size_text);
        formatLine(self.allocator, body_size_text, box_width, blue, reset, cyan, reset) catch {};

        const buffer_size_text = std.fmt.allocPrint(self.allocator, "  * Buffer Size: {d} KB", .{self.config.buffer_size / 1024}) catch "  * Buffer Size: 8 KB";
        defer if (!std.mem.eql(u8, buffer_size_text, "  * Buffer Size: 8 KB")) self.allocator.free(buffer_size_text);
        formatLine(self.allocator, buffer_size_text, box_width, blue, reset, cyan, reset) catch {};

        print("{s}{s}{s}\n", .{ cyan, separator, reset });

        if (self.router) |router| {
            formatLine(self.allocator, "[ROUTES] Available Routes:", box_width, yellow, reset, cyan, reset) catch {};
            print("{s}{s}{s}\n", .{ cyan, separator, reset });

            if (router.routes.items.len > 0) {
                for (router.routes.items) |route| {
                    const method_color = switch (route.method) {
                        .GET => "\x1b[32m", // Green
                        .POST => "\x1b[33m", // Yellow
                        .PUT => "\x1b[34m", // Blue
                        .DELETE => "\x1b[31m", // Red
                        .PATCH => "\x1b[35m", // Magenta
                        .OPTIONS => "\x1b[36m", // Cyan
                        .HEAD => "\x1b[37m", // White
                    };

                    const method_str = @tagName(route.method);
                    const route_text = std.fmt.allocPrint(self.allocator, "{s:<7} {s}", .{ method_str, route.path }) catch "Route";
                    defer if (!std.mem.eql(u8, route_text, "Route")) self.allocator.free(route_text);
                    formatLine(self.allocator, route_text, box_width, method_color, reset, cyan, reset) catch {};
                }
            } else {
                formatLine(self.allocator, "  No routes configured", box_width, yellow, reset, cyan, reset) catch {};
            }
        } else {
            formatLine(self.allocator, "[WARNING] No router configured", box_width, yellow, reset, cyan, reset) catch {};
        }

        print("{s}{s}{s}\n", .{ cyan, separator, reset });
        print("{s}[READY] Server ready to handle requests!{s}\n\n", .{ bold, reset });
    }

    fn handleConnection(self: *Server, connection: net.Server.Connection) !void {
        defer connection.stream.close();

        var buffer = try self.allocator.alloc(u8, self.config.buffer_size);
        defer self.allocator.free(buffer);

        const bytes_read = connection.stream.read(buffer) catch |err| switch (err) {
            error.ConnectionResetByPeer, error.BrokenPipe => return,
            else => return err,
        };

        if (bytes_read == 0) return;

        const request_data = buffer[0..bytes_read];

        // Check request size limit
        if (request_data.len > self.config.max_body_size) {
            try self.sendErrorResponse(connection.stream, .BAD_REQUEST, "Request too large");
            return;
        }

        // Parse HTTP request
        var req = self.parseRequest(request_data) catch |err| switch (err) {
            ServerError.InvalidRequest => {
                try self.sendErrorResponse(connection.stream, .BAD_REQUEST, "Invalid request format");
                return;
            },
            else => return err,
        };
        defer req.deinit();

        var res = Response.init(self.allocator);
        defer res.deinit();

        // Add CORS headers if enabled
        if (self.config.cors_enabled) {
            try self.addCorsHeaders(&res);
        }

        // Handle the request with router
        if (self.router) |router| {
            try router.handle(&req, &res);
        } else {
            try self.sendErrorResponse(connection.stream, .INTERNAL_SERVER_ERROR, "No router configured");
            return;
        }

        // Send response
        try self.sendResponse(connection.stream, &res);

        if (self.config.enable_logging) {
            self.logRequest(&req, &res);
        }
    }
    fn addCorsHeaders(self: *Server, res: *Response) !void {
        _ = self;
        _ = try res.header("Access-Control-Allow-Origin", "*");
        _ = try res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
        _ = try res.header("Access-Control-Allow-Headers", "Content-Type, Authorization");
    }

    fn logRequest(self: *Server, req: *Request, res: *Response) void {
        _ = self;
        const status_code = @intFromEnum(res.status_code);
        const method_name = @tagName(req.method);
        const status_emoji = if (status_code >= 200 and status_code < 300) "[OK]" else if (status_code >= 400 and status_code < 500) "[WARN]" else "[ERROR]";

        print("{s} {s} {s} -> {d}\n", .{ status_emoji, method_name, req.path, status_code });
    }

    fn parseRequest(self: *Server, data: []const u8) !Request {
        var req = Request.init(self.allocator);

        var lines = std.mem.splitSequence(u8, data, "\r\n");
        const first_line = lines.next() orelse return ServerError.InvalidRequest;

        // Validate first line is not empty
        if (first_line.len == 0) return ServerError.InvalidRequest;

        var parts = std.mem.splitSequence(u8, first_line, " ");
        const method_str = parts.next() orelse return ServerError.InvalidRequest;
        const path_str = parts.next() orelse return ServerError.InvalidRequest;
        const http_version = parts.next() orelse return ServerError.InvalidRequest;

        // Validate HTTP version
        if (!std.mem.startsWith(u8, http_version, "HTTP/")) {
            return ServerError.InvalidRequest;
        }

        // Parse method with better error handling
        req.method = self.parseHttpMethod(method_str) orelse {
            return ServerError.InvalidRequest;
        };

        // Parse path and query parameters
        if (std.mem.indexOf(u8, path_str, "?")) |query_start| {
            req.path = path_str[0..query_start];
            const query_str = path_str[query_start + 1 ..];
            try self.parseQueryParams(&req, query_str);
        } else {
            req.path = path_str;
        }

        // Validate path
        if (req.path.len == 0 or req.path[0] != '/') {
            return ServerError.InvalidRequest;
        }

        // Parse headers
        var content_length: ?usize = null;
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

                // Store Content-Length for body parsing
                if (std.ascii.eqlIgnoreCase(header_name, "content-length")) {
                    content_length = std.fmt.parseInt(usize, header_value, 10) catch null;
                }

                try req.headers.put(header_name, header_value);
            }
        }

        // Parse body if present and validate against Content-Length
        if (in_body and body_start < data.len) {
            const available_body = data[body_start..];
            if (content_length) |expected_length| {
                if (available_body.len >= expected_length) {
                    req.body = available_body[0..expected_length];
                } else {
                    // Incomplete body - in a real server, you'd wait for more data
                    req.body = available_body;
                }
            } else {
                req.body = available_body;
            }
        }

        return req;
    }

    /// Parses the HTTP method from a string.
    /// Returns null if the method is not recognized.
    fn parseHttpMethod(self: *Server, method_str: []const u8) ?HttpMethod {
        _ = self;
        return if (std.mem.eql(u8, method_str, "GET"))
            .GET
        else if (std.mem.eql(u8, method_str, "POST"))
            .POST
        else if (std.mem.eql(u8, method_str, "PUT"))
            .PUT
        else if (std.mem.eql(u8, method_str, "DELETE"))
            .DELETE
        else if (std.mem.eql(u8, method_str, "PATCH"))
            .PATCH
        else if (std.mem.eql(u8, method_str, "OPTIONS"))
            .OPTIONS
        else if (std.mem.eql(u8, method_str, "HEAD"))
            .HEAD
        else
            null;
    }

    /// Parses query parameters from the request.
    fn parseQueryParams(self: *Server, req: *Request, query_str: []const u8) !void {
        _ = self;
        var params = std.mem.splitSequence(u8, query_str, "&");

        while (params.next()) |param| {
            if (param.len == 0) continue;

            if (std.mem.indexOf(u8, param, "=")) |eq_pos| {
                const key = std.mem.trim(u8, param[0..eq_pos], " \t");
                const value = std.mem.trim(u8, param[eq_pos + 1 ..], " \t");

                if (key.len > 0) {
                    try req.query.put(key, value);
                }
            } else {
                // Handle parameters without values (e.g., ?flag)
                const key = std.mem.trim(u8, param, " \t");
                if (key.len > 0) {
                    try req.query.put(key, "");
                }
            }
        }
    }

    fn sendErrorResponse(self: *Server, stream: net.Stream, status: HttpStatus, message: []const u8) !void {
        var response = std.ArrayList(u8).init(self.allocator);
        defer response.deinit();

        const status_code = @intFromEnum(status);
        const status_text = @tagName(status);

        // Create JSON error response
        const error_json = try std.fmt.allocPrint(self.allocator, "{{\"error\": \"{s}\", \"status\": {d}}}", .{ message, status_code });
        defer self.allocator.free(error_json);

        // Build response
        try response.writer().print("HTTP/1.1 {d} {s}\r\n", .{ status_code, status_text });
        try response.writer().print("Content-Type: application/json\r\n", .{});
        try response.writer().print("Content-Length: {d}\r\n", .{error_json.len});

        if (self.config.cors_enabled) {
            try response.writer().print("Access-Control-Allow-Origin: *\r\n", .{});
        }

        try response.writer().print("\r\n", .{});
        try response.writer().print("{s}", .{error_json});

        _ = try stream.writeAll(response.items);
    }

    fn sendResponse(self: *Server, stream: net.Stream, res: *Response) !void {
        // Build response string
        var response = std.ArrayList(u8).init(self.allocator);
        defer response.deinit();

        const status_code = @intFromEnum(res.status_code);
        const status_text = @tagName(res.status_code);

        // Status line
        try response.writer().print("HTTP/1.1 {d} {s}\r\n", .{ status_code, status_text });

        // Add default headers if not present
        if (!res.headers.contains("Server")) {
            try response.writer().print("Server: Kamari-Zig/1.0\r\n", .{});
        }
        if (!res.headers.contains("Date")) {
            const timestamp = std.time.timestamp();
            try response.writer().print("Date: {d}\r\n", .{timestamp});
        }

        // Custom headers
        var header_iterator = res.headers.iterator();
        while (header_iterator.next()) |entry| {
            try response.writer().print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        // Content-Length header
        if (res.body) |body| {
            try response.writer().print("Content-Length: {d}\r\n", .{body.len});
        } else {
            try response.writer().print("Content-Length: 0\r\n", .{});
        }

        // Connection header
        try response.writer().print("Connection: close\r\n", .{});

        // End of headers
        try response.writer().print("\r\n", .{});

        // Body
        if (res.body) |body| {
            try response.writer().print("{s}", .{body});
        }

        // Send the complete response
        _ = stream.writeAll(response.items) catch |err| switch (err) {
            error.ConnectionResetByPeer, error.BrokenPipe => {
                if (self.config.enable_logging) {
                    print("[WARN] Client disconnected before response could be sent\n", .{});
                }
                return;
            },
            else => return err,
        };
    }
};
