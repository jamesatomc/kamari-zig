const std = @import("std");
const types = @import("types.zig");
const Request = types.Request;
const Response = types.Response;
const RouteHandler = types.RouteHandler;
const MiddlewareHandler = types.MiddlewareHandler;
const HttpMethod = types.HttpMethod;

const Route = struct {
    method: HttpMethod,
    path: []const u8,
    handler: RouteHandler,
    params: [][]const u8,

    pub fn init(method: HttpMethod, path: []const u8, handler: RouteHandler) Route {
        return Route{
            .method = method,
            .path = path,
            .handler = handler,
            .params = &[_][]const u8{},
        };
    }
};

const Middleware = struct {
    handler: MiddlewareHandler,

    pub fn init(handler: MiddlewareHandler) Middleware {
        return Middleware{
            .handler = handler,
        };
    }
};

pub const Router = struct {
    routes: std.ArrayList(Route),
    middlewares: std.ArrayList(Middleware),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Router {
        return Router{
            .routes = std.ArrayList(Route).init(allocator),
            .middlewares = std.ArrayList(Middleware).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Router) void {
        self.routes.deinit();
        self.middlewares.deinit();
    }

    pub fn use(self: *Router, middleware: MiddlewareHandler) !void {
        try self.middlewares.append(Middleware.init(middleware));
    }

    pub fn get(self: *Router, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.GET, path, handler);
    }

    pub fn post(self: *Router, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.POST, path, handler);
    }

    pub fn put(self: *Router, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.PUT, path, handler);
    }

    pub fn delete(self: *Router, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.DELETE, path, handler);
    }

    pub fn patch(self: *Router, path: []const u8, handler: RouteHandler) !void {
        try self.addRoute(.PATCH, path, handler);
    }

    fn addRoute(self: *Router, method: HttpMethod, path: []const u8, handler: RouteHandler) !void {
        const route = Route.init(method, path, handler);
        try self.routes.append(route);
    }

    pub fn handle(self: *Router, req: *Request, res: *Response) !void {
        // Execute middlewares first
        for (self.middlewares.items) |middleware| {
            // For simplicity, we'll call middleware without proper next() implementation
            // In a real implementation, you'd want to implement proper middleware chaining
            try middleware.handler(req, res, &emptyNext);
        }

        // Find matching route
        for (self.routes.items) |route| {
            if (route.method == req.method and self.matchPath(route.path, req.path, req)) {
                try route.handler(req, res);
                return;
            }
        }

        // No route found - 404
        _ = res.status(404);
        const ErrorResponse = struct { @"error": []const u8 };
        const error_data = ErrorResponse{ .@"error" = "Route not found" };
        try res.json(error_data);
    }

    fn matchPath(self: *Router, routePath: []const u8, reqPath: []const u8, req: *Request) bool {
        // Simple path matching - can be enhanced for parameter extraction
        if (std.mem.indexOf(u8, routePath, ":")) |_| {
            // Handle parameterized routes (simple implementation)
            return self.matchParameterizedPath(routePath, reqPath, req);
        }

        return std.mem.eql(u8, routePath, reqPath);
    }

    fn matchParameterizedPath(_: *Router, routePath: []const u8, reqPath: []const u8, req: *Request) bool {
        var route_parts = std.mem.splitSequence(u8, routePath, "/");
        var req_parts = std.mem.splitSequence(u8, reqPath, "/");

        while (route_parts.next()) |route_part| {
            const req_part = req_parts.next() orelse return false;

            if (route_part.len > 0 and route_part[0] == ':') {
                // This is a parameter
                const param_name = route_part[1..];
                req.params.put(param_name, req_part) catch return false;
            } else if (!std.mem.eql(u8, route_part, req_part)) {
                return false;
            }
        }

        return req_parts.next() == null;
    }
};

fn emptyNext() !void {
    // Empty next function for middleware
}
