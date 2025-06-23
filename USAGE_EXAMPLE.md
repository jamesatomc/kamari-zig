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
    .name = "my-web-app",
    .version = "0.1.0",
    .dependencies = .{
        .kamari = .{
            .url = "https://github.com/jamesatomc/kamari-zig.git",
            // The hash will be automatically computed when you run zig build
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

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

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

    var server = kamari.Server.init(allocator);
    defer server.deinit();

    var router = kamari.Router.init(allocator);
    defer router.deinit();

    // Add middleware
    try router.use(kamari.middleware.cors);
    try router.use(kamari.middleware.logger);

    // Define routes
    try router.get("/", handleHome);
    try router.get("/api/hello/:name", handleHello);

    std.debug.print("Starting server on http://127.0.0.1:8080\n", .{});
    try server.listen("127.0.0.1", 8080, &router);
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
