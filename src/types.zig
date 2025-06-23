const std = @import("std");

pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    OPTIONS,
    HEAD,
};

pub const HttpStatus = enum(u16) {
    OK = 200,
    CREATED = 201,
    NO_CONTENT = 204,
    BAD_REQUEST = 400,
    UNAUTHORIZED = 401,
    FORBIDDEN = 403,
    NOT_FOUND = 404,
    METHOD_NOT_ALLOWED = 405,
    INTERNAL_SERVER_ERROR = 500,
    NOT_IMPLEMENTED = 501,
    BAD_GATEWAY = 502,
    SERVICE_UNAVAILABLE = 503,
};

pub const Headers = std.HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage);

pub const Request = struct {
    method: HttpMethod,
    path: []const u8,
    query: std.HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    params: std.HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage),
    headers: Headers,
    body: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Request {
        return Request{
            .method = .GET,
            .path = "",
            .query = std.HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .params = std.HashMap([]const u8, []const u8, std.hash_map.StringContext, std.hash_map.default_max_load_percentage).init(allocator),
            .headers = Headers.init(allocator),
            .body = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Request) void {
        self.query.deinit();
        self.params.deinit();
        self.headers.deinit();
    }
};

pub const Response = struct {
    status_code: HttpStatus,
    headers: Headers,
    body: ?[]const u8,
    allocator: std.mem.Allocator,
    sent: bool,

    pub fn init(allocator: std.mem.Allocator) Response {
        return Response{
            .status_code = .OK,
            .headers = Headers.init(allocator),
            .body = null,
            .allocator = allocator,
            .sent = false,
        };
    }

    pub fn deinit(self: *Response) void {
        self.headers.deinit();
        if (self.body) |body| {
            self.allocator.free(body);
        }
    }

    pub fn status(self: *Response, code: u16) *Response {
        self.status_code = @enumFromInt(code);
        return self;
    }

    pub fn header(self: *Response, name: []const u8, value: []const u8) !*Response {
        try self.headers.put(name, value);
        return self;
    }

    pub fn json(self: *Response, data: anytype) !void {
        _ = try self.header("Content-Type", "application/json");

        var json_string = std.ArrayList(u8).init(self.allocator);
        defer json_string.deinit();

        try std.json.stringify(data, .{}, json_string.writer());

        self.body = try self.allocator.dupe(u8, json_string.items);
        self.sent = true;
    }

    pub fn send(self: *Response, data: []const u8) !void {
        self.body = try self.allocator.dupe(u8, data);
        self.sent = true;
    }

    pub fn text(self: *Response, data: []const u8) !void {
        _ = try self.header("Content-Type", "text/plain");
        try self.send(data);
    }

    pub fn html(self: *Response, data: []const u8) !void {
        _ = try self.header("Content-Type", "text/html");
        try self.send(data);
    }
};

pub const RouteHandler = *const fn (req: *const Request, res: *Response) anyerror!void;
pub const MiddlewareHandler = *const fn (req: *const Request, res: *Response, next: *const fn () anyerror!void) anyerror!void;
