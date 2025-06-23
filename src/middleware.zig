const std = @import("std");
const types = @import("types.zig");
const Request = types.Request;
const Response = types.Response;
const print = std.debug.print;

// CORS Middleware
pub fn cors(req: *const Request, res: *Response, next: *const fn () anyerror!void) !void {
    _ = req;

    _ = try res.header("Access-Control-Allow-Origin", "*");
    _ = try res.header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS");
    _ = try res.header("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With");
    _ = try res.header("Access-Control-Max-Age", "86400");

    try next();
}

// Logger Middleware
pub fn logger(req: *const Request, res: *Response, next: *const fn () anyerror!void) !void {
    const timestamp = std.time.timestamp();
    print("[{}] {s} {s}\n", .{ timestamp, @tagName(req.method), req.path });

    _ = res;
    try next();
}

// JSON Parser Middleware
pub fn jsonParser(req: *const Request, res: *Response, next: *const fn () anyerror!void) !void {
    if (req.body) |body| {
        if (req.headers.get("content-type")) |content_type| {
            if (std.mem.indexOf(u8, content_type, "application/json")) |_| {
                print("Parsing JSON body: {s}\n", .{body});
                // In a real implementation, you would parse the JSON here
                // and attach it to the request object
            }
        }
    }

    _ = res;
    try next();
}

// Authentication Middleware
pub fn auth(req: *const Request, res: *Response, next: *const fn () anyerror!void) !void {
    if (req.headers.get("authorization")) |auth_header| {
        if (std.mem.startsWith(u8, auth_header, "Bearer ")) {
            const token = auth_header[7..];
            print("Validating token: {s}\n", .{token});
            // In a real implementation, you would validate the JWT token here
            try next();
            return;
        }
    }

    _ = res.status(401);
    const ErrorResponse = struct { @"error": []const u8 };
    const error_data = ErrorResponse{ .@"error" = "Unauthorized" };
    try res.json(error_data);
}

// Rate Limiting Middleware (simple implementation)
pub fn rateLimit(req: *const Request, res: *Response, next: *const fn () anyerror!void) !void {
    // In a real implementation, you would track requests per IP
    // and implement proper rate limiting logic

    print("Rate limit check for path: {s}\n", .{req.path});

    _ = res;
    try next();
}

// Request Size Limit Middleware
pub fn bodyLimit(req: *const Request, res: *Response, next: *const fn () anyerror!void) !void {
    const max_size = 1024 * 1024; // 1MB limit

    if (req.body) |body| {
        if (body.len > max_size) {
            _ = res.status(413);
            const ErrorResponse = struct { @"error": []const u8 };
            const error_data = ErrorResponse{ .@"error" = "Request entity too large" };
            try res.json(error_data);
            return;
        }
    }

    try next();
}
