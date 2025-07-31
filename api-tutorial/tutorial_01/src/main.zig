//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");
const kamari = @import("kamari");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create server configuration
    const config = kamari.ServerConfig{
        .max_connections = 100,
        .buffer_size = 8192,
        .timeout_ms = 30000,
        .enable_logging = true,
        .cors_enabled = true,
        .max_body_size = 1024 * 1024, // 1MB
    };

    // Create server and router
    var server = kamari.Server.init(allocator, config);
    defer server.deinit();

    var router = kamari.Router.init(allocator);
    defer router.deinit();

    // Add middleware
    try router.use(kamari.middleware.cors);
    try router.use(kamari.middleware.logger);

    // Define routes
    try router.get("/", handleHome);
    try router.get("/users/:id", handleUser);
    try router.post("/users", handleCreateUser);

    // Set router to server
    server.setRouter(&router);

    // Start server
    try server.listen("127.0.0.1", 8080);
}

fn handleHome(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const data = .{ .message = "Hello, Kamari-Zig!" };
    try res.json(data);
}

fn handleUser(req: *const kamari.Request, res: *kamari.Response) !void {
    const user_id = req.params.get("id") orelse "unknown";
    const data = .{ .id = user_id, .name = "User Name" };
    try res.json(data);
}

fn handleCreateUser(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req; // Mark req as used to avoid unused parameter warning
    // Handle POST data from req.body
    const data = .{ .message = "User created", .id = 123 };
    _ = res.status(201);
    try res.json(data);
}
