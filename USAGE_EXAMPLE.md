# How to Use Kamari-Zig in Your Project

This example shows how to use kamari-zig as a dependency in another Zig project.

## Step 1: Create a new Zig project

```bash
mkdir my-web-app
cd my-web-app
zig init
```

## Step 2: Add kamari-zig as a dependency

Edit your `build.zig.zon` file:

```zon
.{
    .name = ,
    .version = "0.1.0",
    .fingerprint = 0xde9d4c86ff906cdd,
    .minimum_zig_version = "0.14.1",
    .dependencies = .{
        .kamari = .{
            .url = "https://github.com/jamesatomc/kamari-zig/archive/main.tar.gz",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

## Step 3: Update your build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add kamari dependency
    const kamari_dep = b.dependency("kamari", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-web-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import kamari module
    exe.root_module.addImport("kamari", kamari_dep.module("kamari"));

    b.installArtifact(exe);

    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
```

## Step 4: Create your main.zig

```zig
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

    var server = kamari.Server.init(allocator, config);
    defer server.deinit();

    var router = kamari.Router.init(allocator);
    defer router.deinit();

    // Add middleware
    try router.use(kamari.middleware.cors);
    try router.use(kamari.middleware.logger);

    // Define routes
    try router.get("/", handleHome);
    try router.get("/api/hello/:name", handleHello);

    // Set router to server
    server.setRouter(&router);

    std.debug.print("Starting server on http://127.0.0.1:8080\n", .{});
    try server.listen("127.0.0.1", 8080);
}

fn handleHome(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const data = .{
        .message = "Welcome to my web app!",
        .powered_by = "kamari-zig v" ++ kamari.version,
    };
    try res.json(data);
}

fn handleHello(req: *const kamari.Request, res: *kamari.Response) !void {
    const name = req.params.get("name") orelse "World";
    const data = .{
        .greeting = "Hello, " ++ name ++ "!",
        .timestamp = std.time.timestamp(),
    };
    try res.json(data);
}
```

## Step 5: Build and run

```bash
zig build
zig build run
```

Your web server will start on http://127.0.0.1:8080

## Available endpoints:

- `GET /` - Welcome message
- `GET /api/hello/:name` - Personalized greeting

That's it! You now have a working web server using the kamari-zig framework.

## Exploring the Framework with Semantic Search

You can use semantic search to explore and understand the Kamari-Zig framework better. Here are some examples:

### 1. Finding Middleware Examples
When you search for middleware-related code, you'll discover:

**Built-in Middleware Available:**
- `kamari.middleware.cors` - Cross-Origin Resource Sharing support
- `kamari.middleware.logger` - Request logging functionality  
- `kamari.middleware.jsonParser` - JSON body parsing
- `kamari.middleware.auth` - Authentication middleware
- `kamari.middleware.rateLimit` - Rate limiting functionality
- `kamari.middleware.bodyLimit` - Request size limiting

**Example Usage:**
```zig
// Add multiple middleware to your router
try router.use(kamari.middleware.cors);
try router.use(kamari.middleware.logger);
try router.use(kamari.middleware.jsonParser);
try router.use(kamari.middleware.auth);
```

### 2. Understanding Server Configuration
The `ServerConfig` struct provides comprehensive server settings:

```zig
const config = kamari.ServerConfig{
    .max_connections = 100,        // Maximum concurrent connections
    .buffer_size = 8192,          // Buffer size for reading requests (8KB)
    .timeout_ms = 30000,          // Request timeout in milliseconds (30 seconds)
    .enable_logging = true,       // Enable/disable request logging
    .cors_enabled = true,         // Enable/disable CORS headers
    .max_body_size = 1024 * 1024, // Maximum request body size (1MB)
};
```

### 3. Working with HTTP Types
The framework provides comprehensive HTTP type definitions:

**HTTP Methods:**
- `kamari.HttpMethod.GET`
- `kamari.HttpMethod.POST`
- `kamari.HttpMethod.PUT`
- `kamari.HttpMethod.DELETE`
- `kamari.HttpMethod.PATCH`
- `kamari.HttpMethod.OPTIONS`
- `kamari.HttpMethod.HEAD`

**HTTP Status Codes:**
- `kamari.HttpStatus.OK` (200)
- `kamari.HttpStatus.CREATED` (201)
- `kamari.HttpStatus.BAD_REQUEST` (400)
- `kamari.HttpStatus.UNAUTHORIZED` (401)
- `kamari.HttpStatus.NOT_FOUND` (404)
- `kamari.HttpStatus.INTERNAL_SERVER_ERROR` (500)

### 4. Request and Response Handling Examples
Based on the framework's capabilities, here are practical examples:

**Handling Route Parameters:**
```zig
fn handleUser(req: *const kamari.Request, res: *kamari.Response) !void {
    // Extract route parameters like /users/:id
    const user_id = req.params.get("id") orelse "unknown";
    
    // Extract query parameters like ?search=term&page=1
    const search_term = req.query.get("search");
    const page = req.query.get("page") orelse "1";
    
    const data = .{
        .user_id = user_id,
        .search = search_term,
        .page = page,
    };
    
    try res.json(data);
}
```

**Handling POST Requests with JSON:**
```zig
fn handleCreateUser(req: *const kamari.Request, res: *kamari.Response) !void {
    if (req.body) |body| {
        // The jsonParser middleware will have processed the JSON
        std.debug.print("Received JSON: {s}\n", .{body});
        
        // Create response
        const response_data = .{
            .message = "User created successfully",
            .received_data = body,
            .timestamp = std.time.timestamp(),
        };
        
        _ = res.status(201); // Set status to Created
        try res.json(response_data);
    } else {
        _ = res.status(400); // Bad Request
        const error_data = .{ .error = "Missing request body" };
        try res.json(error_data);
    }
}
```

### 5. Custom Middleware Creation
You can create your own middleware following this pattern:

```zig
fn customMiddleware(req: *const kamari.Request, res: *kamari.Response, next: *const fn () anyerror!void) !void {
    // Pre-processing: runs before the route handler
    std.debug.print("Request to: {s}\n", .{req.path});
    
    // Add custom headers
    _ = try res.header("X-Custom-Header", "My-Value");
    
    // Call the next middleware/handler in the chain
    try next();
    
    // Post-processing: runs after the route handler
    std.debug.print("Response sent for: {s}\n", .{req.path});
}

// Register the middleware
try router.use(customMiddleware);
```

### 6. Complete Working Example with Advanced Features

```zig
const std = @import("std");
const kamari = @import("kamari");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Configure server with custom settings
    const config = kamari.ServerConfig{
        .max_connections = 50,
        .buffer_size = 4096,
        .timeout_ms = 15000,
        .enable_logging = true,
        .cors_enabled = true,
        .max_body_size = 512 * 1024, // 512KB
    };

    var server = kamari.Server.init(allocator, config);
    defer server.deinit();

    var router = kamari.Router.init(allocator);
    defer router.deinit();

    // Add comprehensive middleware stack
    try router.use(kamari.middleware.cors);
    try router.use(kamari.middleware.logger);
    try router.use(kamari.middleware.jsonParser);
    try router.use(kamari.middleware.bodyLimit);

    // Define API routes
    try router.get("/", handleHome);
    try router.get("/api/status", handleStatus);
    try router.get("/api/users/:id", handleGetUser);
    try router.post("/api/users", handleCreateUser);
    try router.put("/api/users/:id", handleUpdateUser);
    try router.delete("/api/users/:id", handleDeleteUser);

    // Set router and start server
    server.setRouter(&router);
    
    std.debug.print("🚀 Advanced Kamari-Zig server starting...\n", .{});
    std.debug.print("📡 Listening on http://127.0.0.1:8080\n", .{});
    
    try server.listen("127.0.0.1", 8080);
}

fn handleHome(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const data = .{
        .message = "Welcome to Advanced Kamari-Zig API",
        .version = kamari.version,
        .endpoints = .{
            .status = "/api/status",
            .users = "/api/users",
            .user_detail = "/api/users/:id",
        },
    };
    try res.json(data);
}

fn handleStatus(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const data = .{
        .status = "healthy",
        .timestamp = std.time.timestamp(),
        .framework = "kamari-zig",
        .version = kamari.version,
    };
    try res.json(data);
}

fn handleGetUser(req: *const kamari.Request, res: *kamari.Response) !void {
    const user_id = req.params.get("id") orelse "0";
    const include_profile = req.query.get("include_profile");
    
    const data = .{
        .id = user_id,
        .name = "Sample User",
        .email = "user@example.com",
        .profile = if (include_profile != null) .{
            .bio = "Sample bio",
            .location = "Sample City",
        } else null,
    };
    
    try res.json(data);
}

fn handleCreateUser(req: *const kamari.Request, res: *kamari.Response) !void {
    if (req.body) |body| {
        const data = .{
            .message = "User created successfully",
            .id = 123,
            .received_data = body,
            .created_at = std.time.timestamp(),
        };
        
        _ = res.status(201);
        try res.json(data);
    } else {
        _ = res.status(400);
        const error_data = .{ .error = "Request body is required" };
        try res.json(error_data);
    }
}

fn handleUpdateUser(req: *const kamari.Request, res: *kamari.Response) !void {
    const user_id = req.params.get("id") orelse "0";
    
    if (req.body) |body| {
        const data = .{
            .message = "User updated successfully",
            .id = user_id,
            .received_data = body,
            .updated_at = std.time.timestamp(),
        };
        
        try res.json(data);
    } else {
        _ = res.status(400);
        const error_data = .{ .error = "Request body is required" };
        try res.json(error_data);
    }
}

fn handleDeleteUser(req: *const kamari.Request, res: *kamari.Response) !void {
    const user_id = req.params.get("id") orelse "0";
    
    const data = .{
        .message = "User deleted successfully",
        .deleted_id = user_id,
        .deleted_at = std.time.timestamp(),
    };
    
    try res.json(data);
}
```

This advanced example demonstrates the full capabilities of the Kamari-Zig framework that you can discover through semantic search exploration.
