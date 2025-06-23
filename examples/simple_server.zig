const std = @import("std");
const kamari = @import("kamari");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var server = kamari.Server.init(allocator);
    defer server.deinit();

    var router = kamari.Router.init(allocator);
    defer router.deinit();

    // Add CORS and logging middleware
    try router.use(kamari.middleware.cors);
    try router.use(kamari.middleware.logger);

    // Simple routes
    try router.get("/", handleHome);
    try router.get("/hello/:name", handleHello);
    try router.post("/echo", handleEcho);

    std.debug.print("Starting Kamari-Zig server on http://127.0.0.1:3000\n", .{});
    try server.listen("127.0.0.1", 3000, &router);
}

fn handleHome(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const response = .{
        .message = "Welcome to Kamari-Zig!",
        .version = kamari.version,
        .endpoints = .{
            .hello = "/hello/:name",
            .echo = "/echo (POST)",
        },
    };
    try res.json(response);
}

fn handleHello(req: *const kamari.Request, res: *kamari.Response) !void {
    const name = req.params.get("name") orelse "World";
    const response = .{
        .message = "Hello, " ++ name ++ "!",
        .timestamp = std.time.timestamp(),
    };
    try res.json(response);
}

fn handleEcho(req: *const kamari.Request, res: *kamari.Response) !void {
    if (req.body) |body| {
        const response = .{
            .echo = body,
            .length = body.len,
        };
        try res.json(response);
    } else {
        _ = res.status(400);
        const error_response = .{ .@"error" = "No body provided" };
        try res.json(error_response);
    }
}
