const std = @import("std");
const print = std.debug.print;
const Server = @import("server.zig").Server;
const Router = @import("router.zig").Router;
const middleware = @import("middleware.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create server instance
    var server = Server.init(allocator);
    defer server.deinit();

    // Create router
    var router = Router.init(allocator);
    defer router.deinit();

    // Add middleware
    try router.use(middleware.cors);
    try router.use(middleware.logger);
    try router.use(middleware.jsonParser);

    // Define routes
    try setupRoutes(&router);

    // Start server
    try server.listen("127.0.0.1", 8080, &router);
}

fn setupRoutes(router: *Router) !void {
    // API routes
    try router.get("/", handleHome);
    try router.get("/api/health", handleHealth);
    try router.get("/api/users", handleGetUsers);
    try router.post("/api/users", handleCreateUser);
    try router.get("/api/users/:id", handleGetUser);
    try router.put("/api/users/:id", handleUpdateUser);
    try router.delete("/api/users/:id", handleDeleteUser);
}

// Route handlers
fn handleHome(req: *const @import("types.zig").Request, res: *@import("types.zig").Response) !void {
    _ = req;
    const WelcomeResponse = struct {
        message: []const u8,
        version: []const u8,
        endpoints: struct {
            health: []const u8,
            users: []const u8,
        },
    };
    const welcome_data = WelcomeResponse{
        .message = "Welcome to Zig API Framework",
        .version = "1.0.0",
        .endpoints = .{
            .health = "/api/health",
            .users = "/api/users",
        },
    };
    try res.json(welcome_data);
}

fn handleHealth(req: *const @import("types.zig").Request, res: *@import("types.zig").Response) !void {
    _ = req;
    const HealthResponse = struct {
        status: []const u8,
        timestamp: i64,
        uptime: []const u8,
    };
    const health_data = HealthResponse{
        .status = "ok",
        .timestamp = std.time.timestamp(),
        .uptime = "running",
    };
    try res.json(health_data);
}

fn handleGetUsers(req: *const @import("types.zig").Request, res: *@import("types.zig").Response) !void {
    _ = req;
    const User = struct {
        id: u32,
        name: []const u8,
        email: []const u8,
    };
    const UsersResponse = struct {
        users: []const User,
    };
    const users_data = UsersResponse{
        .users = &[_]User{
            User{ .id = 1, .name = "John Doe", .email = "john@example.com" },
            User{ .id = 2, .name = "Jane Smith", .email = "jane@example.com" },
        },
    };
    try res.json(users_data);
}

fn handleCreateUser(req: *const @import("types.zig").Request, res: *@import("types.zig").Response) !void {
    // Parse JSON body
    if (req.body) |body| {
        print("Creating user with data: {s}\n", .{body});
        const CreateUserResponse = struct {
            id: u32,
            name: []const u8,
            email: []const u8,
            message: []const u8,
        };
        const create_data = CreateUserResponse{
            .id = 3,
            .name = "New User",
            .email = "new@example.com",
            .message = "User created successfully",
        };
        _ = res.status(201);
        try res.json(create_data);
    } else {
        const ErrorResponse = struct { @"error": []const u8 };
        const error_data = ErrorResponse{ .@"error" = "Invalid request body" };
        _ = res.status(400);
        try res.json(error_data);
    }
}

fn handleGetUser(req: *const @import("types.zig").Request, res: *@import("types.zig").Response) !void {
    if (req.params.get("id")) |id| {
        const UserResponse = struct {
            id: u32,
            name: []const u8,
            email: []const u8,
        };
        const user_data = UserResponse{
            .id = std.fmt.parseInt(u32, id, 10) catch 1,
            .name = "User Name",
            .email = "user@example.com",
        };
        try res.json(user_data);
    } else {
        const ErrorResponse = struct { @"error": []const u8 };
        const error_data = ErrorResponse{ .@"error" = "User ID is required" };
        _ = res.status(400);
        try res.json(error_data);
    }
}

fn handleUpdateUser(req: *const @import("types.zig").Request, res: *@import("types.zig").Response) !void {
    if (req.params.get("id")) |id| {
        if (req.body) |body| {
            print("Updating user {s} with data: {s}\n", .{ id, body });
            const UpdateResponse = struct {
                id: u32,
                message: []const u8,
            };
            const update_data = UpdateResponse{
                .id = std.fmt.parseInt(u32, id, 10) catch 1,
                .message = "User updated successfully",
            };
            try res.json(update_data);
        } else {
            const ErrorResponse = struct { @"error": []const u8 };
            const error_data = ErrorResponse{ .@"error" = "Invalid request body" };
            _ = res.status(400);
            try res.json(error_data);
        }
    } else {
        const ErrorResponse = struct { @"error": []const u8 };
        const error_data = ErrorResponse{ .@"error" = "User ID is required" };
        _ = res.status(400);
        try res.json(error_data);
    }
}

fn handleDeleteUser(req: *const @import("types.zig").Request, res: *@import("types.zig").Response) !void {
    if (req.params.get("id")) |id| {
        print("Deleting user {s}\n", .{id});
        _ = res.status(204);
        try res.send("");
    } else {
        const ErrorResponse = struct { @"error": []const u8 };
        const error_data = ErrorResponse{ .@"error" = "User ID is required" };
        _ = res.status(400);
        try res.json(error_data);
    }
}

test "API Framework Tests" {
    std.testing.refAllDecls(@This());
}
