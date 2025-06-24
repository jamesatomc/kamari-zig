# Kamari-Zig

A fast and lightweight HTTP web framework for Zig, inspired by modern web frameworks.

## Features

- **Fast HTTP Server**: Built on Zig's standard library networking
- **Flexible Routing**: Support for dynamic routes with parameters
- **Middleware System**: Composable middleware for cross-cutting concerns
- **JSON Support**: Built-in JSON parsing and response generation
- **Type Safety**: Full type safety with Zig's powerful type system
- **Zero Dependencies**: Uses only Zig's standard library

## Installation

### Using Zig Package Manager

Add kamari-zig to your `build.zig.zon`:

```zon
.{
    .name = "your-project",
    .version = "0.1.0",
    .minimum_zig_version = "0.14.1",
    .dependencies = .{
        .kamari = .{
            .url = "https://github.com/jamesatomc/kamari-zig/archive/main.tar.gz",
            // Hash will be computed automatically when you run `zig build`
        },
    },
}
}
```

Then in your `build.zig`:

```zig
const kamari_dep = b.dependency("kamari", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("kamari", kamari_dep.module("kamari"));
```

### Manual Installation

Clone the repository and include it in your project:

```bash
git clone https://github.com/jamesatomc/kamari-zig.git
```

## Quick Start

```zig
const std = @import("std");
const kamari = @import("kamari");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create server and router
    var server = kamari.Server.init(allocator);
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

    // Start server
    try server.listen("127.0.0.1", 8080, &router);
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
    // Handle POST data from req.body
    const data = .{ .message = "User created", .id = 123 };
    _ = res.status(201);
    try res.json(data);
}
```

## API Documentation

### Server

```zig
const server = kamari.Server.init(allocator);
try server.listen("127.0.0.1", 8080, &router);
```

### Router

```zig
const router = kamari.Router.init(allocator);

// HTTP methods
try router.get("/path", handler);
try router.post("/path", handler);
try router.put("/path", handler);
try router.delete("/path", handler);

// Dynamic routes
try router.get("/users/:id", handler);
try router.get("/posts/:id/comments/:comment_id", handler);

// Middleware
try router.use(middleware_function);
```

### Request

```zig
fn handler(req: *const kamari.Request, res: *kamari.Response) !void {
    // HTTP method
    const method = req.method; // kamari.HttpMethod

    // Path and parameters
    const path = req.path;
    const user_id = req.params.get("id");

    // Query parameters
    const search = req.query.get("search");

    // Headers
    const content_type = req.headers.get("content-type");

    // Body (for POST/PUT requests)
    if (req.body) |body| {
        // Process request body
    }
}
```

### Response

```zig
fn handler(req: *const kamari.Request, res: *kamari.Response) !void {
    // JSON response
    const data = .{ .message = "Hello, World!" };
    try res.json(data);

    // Text response
    try res.text("Hello, World!");

    // HTML response
    try res.html("<h1>Hello, World!</h1>");

    // Set status code
    _ = res.status(201);
    try res.json(data);

    // Set headers
    _ = try res.header("X-Custom-Header", "value");
    try res.text("Response with custom header");
}
```

### Middleware

```zig
fn customMiddleware(req: *const kamari.Request, res: *kamari.Response, next: *const fn () anyerror!void) !void {
    // Pre-processing
    std.debug.print("Before request processing\n", .{});

    // Call next middleware/handler
    try next();

    // Post-processing
    std.debug.print("After request processing\n", .{});
}

// Built-in middleware
try router.use(kamari.middleware.cors);
try router.use(kamari.middleware.logger);
try router.use(kamari.middleware.jsonParser);
try router.use(kamari.middleware.auth);
try router.use(kamari.middleware.rateLimit);
```

## Examples

Check the `examples/` directory for more comprehensive examples:

- `examples/basic_server.zig` - Basic server with CRUD operations
- Run example: `zig build run`

## Building and Testing

```bash
# Build the library
zig build

# Run tests
zig build test

# Run example
zig build run
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Roadmap

- [ ] WebSocket support
- [ ] Template engine
- [ ] Static file serving
- [ ] Database integration helpers
- [ ] Session management
- [ ] File upload handling
- [ ] Compression middleware
- [ ] Rate limiting improvements
- [ ] Performance optimizations

## Benchmarks

Coming soon...

## Credits

Kamari-Zig is built with ❤️ in Zig.
