//! Kamari-Zig: A fast and lightweight HTTP web framework for Zig
//!
//! This library provides a simple and flexible HTTP server framework
//! with routing, middleware support, and JSON handling capabilities.
//!
//! Example usage:
//! ```zig
//! const kamari = @import("kamari-zig");
//!
//! pub fn main() !void {
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer _ = gpa.deinit();
//!     const allocator = gpa.allocator();
//!
//!     var server = kamari.Server.init(allocator);
//!     defer server.deinit();
//!
//!     var router = kamari.Router.init(allocator);
//!     defer router.deinit();
//!
//!     try router.get("/", handleHome);
//!     try server.listen("127.0.0.1", 8080, &router);
//! }
//! ```

const std = @import("std");

// Re-export core types
pub const HttpMethod = @import("types.zig").HttpMethod;
pub const HttpStatus = @import("types.zig").HttpStatus;
pub const Request = @import("types.zig").Request;
pub const Response = @import("types.zig").Response;
pub const RouteHandler = @import("types.zig").RouteHandler;
pub const MiddlewareHandler = @import("types.zig").MiddlewareHandler;
pub const Headers = @import("types.zig").Headers;

// Re-export main components
pub const Server = @import("server.zig").Server;
pub const Router = @import("router.zig").Router;

// Re-export middleware
pub const middleware = @import("middleware.zig");

// Re-export utilities
pub const utils = @import("utils.zig");

// Version information
pub const version = "0.1.1";

// Library tests
test {
    std.testing.refAllDecls(@This());
}
