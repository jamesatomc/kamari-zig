const std = @import("std");
const print = std.debug.print;
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

    // Create server instance
    var server = kamari.Server.init(allocator, config);
    defer server.deinit();

    // Create router
    var router = kamari.Router.init(allocator);
    defer router.deinit();

    // Add middleware
    try router.use(kamari.middleware.cors);
    try router.use(kamari.middleware.logger);
    try router.use(kamari.middleware.jsonParser);

    // Define routes
    try setupRoutes(&router);

    // Set router to server
    server.setRouter(&router);

    // Start server
    print("🚀 Kamari-Zig server starting on http://127.0.0.1:8080\n", .{});
    print("\n", .{});

    try server.listen("127.0.0.1", 8080);
}

fn setupRoutes(router: *kamari.Router) !void {
    // Home and health routes
    try router.get("/", handleHome);
    try router.get("/api/health", handleHealth);

    // User CRUD routes
    try router.get("/api/users", handleGetUsers);
    try router.post("/api/users", handleCreateUser);
    try router.get("/api/users/:id", handleGetUser);
    try router.put("/api/users/:id", handleUpdateUser);
    try router.delete("/api/users/:id", handleDeleteUser);

    // Additional example routes
    try router.get("/api/products", handleGetProducts);
    try router.get("/api/search", handleSearch);
}

// Route handlers
fn handleHome(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const WelcomeResponse = struct {
        message: []const u8,
        version: []const u8,
        framework_version: []const u8,
        endpoints: struct {
            health: []const u8,
            users: []const u8,
            products: []const u8,
            search: []const u8,
        },
        documentation: []const u8,
    };

    const welcome_data = WelcomeResponse{
        .message = "🎉 ยินดีต้อนรับสู่ Kamari-Zig Framework!",
        .version = "1.0.0",
        .framework_version = kamari.version,
        .endpoints = .{
            .health = "/api/health",
            .users = "/api/users",
            .products = "/api/products",
            .search = "/api/search?q=keyword",
        },
        .documentation = "ดูตัวอย่างการใช้งานเพิ่มเติมใน README.md",
    };

    try res.json(welcome_data);
}

fn handleHealth(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const HealthResponse = struct {
        status: []const u8,
        timestamp: i64,
        uptime: []const u8,
        framework: []const u8,
        memory_usage: struct {
            allocated: []const u8,
            status: []const u8,
        },
    };

    const health_data = HealthResponse{
        .status = "🟢 healthy",
        .timestamp = std.time.timestamp(),
        .uptime = "running",
        .framework = "kamari-zig v" ++ kamari.version,
        .memory_usage = .{
            .allocated = "minimal",
            .status = "optimal",
        },
    };

    try res.json(health_data);
}

fn handleGetUsers(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const User = struct {
        id: u32,
        name: []const u8,
        email: []const u8,
        role: []const u8,
        created_at: []const u8,
    };

    const UsersResponse = struct {
        users: []const User,
        total: u32,
        page: u32,
        per_page: u32,
    };

    const users_data = UsersResponse{
        .users = &[_]User{
            User{
                .id = 1,
                .name = "สมชาย ใจดี",
                .email = "somchai@example.com",
                .role = "admin",
                .created_at = "2024-01-15T10:30:00Z",
            },
            User{
                .id = 2,
                .name = "สมหญิง รักษ์ดี",
                .email = "somying@example.com",
                .role = "user",
                .created_at = "2024-02-20T14:15:00Z",
            },
            User{
                .id = 3,
                .name = "นายทดสอบ ระบบดี",
                .email = "test@example.com",
                .role = "moderator",
                .created_at = "2024-03-10T09:00:00Z",
            },
        },
        .total = 3,
        .page = 1,
        .per_page = 10,
    };

    try res.json(users_data);
}

fn handleCreateUser(req: *const kamari.Request, res: *kamari.Response) !void {
    // Parse JSON body
    if (req.body) |body| {
        print("📝 Creating user with data: {s}\n", .{body});

        const CreateUserResponse = struct {
            id: u32,
            name: []const u8,
            email: []const u8,
            message: []const u8,
            created_at: i64,
        };

        const create_data = CreateUserResponse{
            .id = 4,
            .name = "ผู้ใช้ใหม่",
            .email = "new.user@example.com",
            .message = "✅ สร้างผู้ใช้สำเร็จแล้ว",
            .created_at = std.time.timestamp(),
        };

        _ = res.status(201);
        try res.json(create_data);
    } else {
        const ErrorResponse = struct {
            @"error": []const u8,
            code: []const u8,
            message: []const u8,
        };
        const error_data = ErrorResponse{
            .@"error" = "❌ ข้อมูล request body ไม่ถูกต้อง",
            .code = "INVALID_BODY",
            .message = "กรุณาส่งข้อมูล JSON ที่ถูกต้อง",
        };
        _ = res.status(400);
        try res.json(error_data);
    }
}

fn handleGetUser(req: *const kamari.Request, res: *kamari.Response) !void {
    if (req.params.get("id")) |id| {
        const UserResponse = struct {
            id: u32,
            name: []const u8,
            email: []const u8,
            role: []const u8,
            profile: struct {
                bio: []const u8,
                location: []const u8,
                website: []const u8,
            },
            stats: struct {
                posts: u32,
                followers: u32,
                following: u32,
            },
        };

        const user_data = UserResponse{
            .id = std.fmt.parseInt(u32, id, 10) catch 1,
            .name = "ผู้ใช้ตัวอย่าง",
            .email = "example.user@example.com",
            .role = "user",
            .profile = .{
                .bio = "นักพัฒนาซอฟต์แวร์ที่ชื่นชอบ Zig",
                .location = "กรุงเทพมหานคร, ประเทศไทย",
                .website = "https://example.com",
            },
            .stats = .{
                .posts = 42,
                .followers = 128,
                .following = 89,
            },
        };

        try res.json(user_data);
    } else {
        const ErrorResponse = struct {
            @"error": []const u8,
            code: []const u8,
        };
        const error_data = ErrorResponse{
            .@"error" = "❌ จำเป็นต้องระบุ User ID",
            .code = "MISSING_USER_ID",
        };
        _ = res.status(400);
        try res.json(error_data);
    }
}

fn handleUpdateUser(req: *const kamari.Request, res: *kamari.Response) !void {
    if (req.params.get("id")) |id| {
        if (req.body) |body| {
            print("📝 Updating user {s} with data: {s}\n", .{ id, body });

            const UpdateResponse = struct {
                id: u32,
                name: []const u8,
                email: []const u8,
                message: []const u8,
                updated_at: i64,
            };

            const update_data = UpdateResponse{
                .id = std.fmt.parseInt(u32, id, 10) catch 1,
                .name = "ผู้ใช้ที่อัปเดต",
                .email = "updated.user@example.com",
                .message = "✅ อัปเดตข้อมูลผู้ใช้สำเร็จแล้ว",
                .updated_at = std.time.timestamp(),
            };

            try res.json(update_data);
        } else {
            const ErrorResponse = struct {
                @"error": []const u8,
                code: []const u8,
            };
            const error_data = ErrorResponse{
                .@"error" = "❌ ข้อมูล request body ไม่ถูกต้อง",
                .code = "INVALID_BODY",
            };
            _ = res.status(400);
            try res.json(error_data);
        }
    } else {
        const ErrorResponse = struct {
            @"error": []const u8,
            code: []const u8,
        };
        const error_data = ErrorResponse{
            .@"error" = "❌ จำเป็นต้องระบุ User ID",
            .code = "MISSING_USER_ID",
        };
        _ = res.status(400);
        try res.json(error_data);
    }
}

fn handleDeleteUser(req: *const kamari.Request, res: *kamari.Response) !void {
    if (req.params.get("id")) |id| {
        print("🗑️  Deleting user {s}\n", .{id});

        const DeleteResponse = struct {
            message: []const u8,
            deleted_id: []const u8,
            timestamp: i64,
        };

        const delete_data = DeleteResponse{
            .message = "✅ ลบผู้ใช้สำเร็จแล้ว",
            .deleted_id = id,
            .timestamp = std.time.timestamp(),
        };

        _ = res.status(200);
        try res.json(delete_data);
    } else {
        const ErrorResponse = struct {
            @"error": []const u8,
            code: []const u8,
        };
        const error_data = ErrorResponse{
            .@"error" = "❌ จำเป็นต้องระบุ User ID",
            .code = "MISSING_USER_ID",
        };
        _ = res.status(400);
        try res.json(error_data);
    }
}

fn handleGetProducts(req: *const kamari.Request, res: *kamari.Response) !void {
    // ตัวอย่างการใช้ query parameters
    const page = req.query.get("page") orelse "1";
    const limit = req.query.get("limit") orelse "10";
    const category = req.query.get("category");

    const Product = struct {
        id: u32,
        name: []const u8,
        price: f64,
        category: []const u8,
        in_stock: bool,
        description: []const u8,
    };

    const ProductsResponse = struct {
        products: []const Product,
        pagination: struct {
            page: []const u8,
            limit: []const u8,
            total: u32,
            has_next: bool,
        },
        filters: struct {
            category: ?[]const u8,
        },
    };

    const products_data = ProductsResponse{
        .products = &[_]Product{
            Product{
                .id = 1,
                .name = "แล็ปท็อป Gaming สุดแรง",
                .price = 45000.00,
                .category = "อิเล็กทรอนิกส์",
                .in_stock = true,
                .description = "แล็ปท็อปเกมมิ่งประสิทธิภาพสูง RAM 32GB",
            },
            Product{
                .id = 2,
                .name = "หูฟังไร้สาย Premium",
                .price = 8500.00,
                .category = "อุปกรณ์เสียง",
                .in_stock = true,
                .description = "หูฟังไร้สายเสียงใสคุณภาพ Hi-Fi",
            },
            Product{
                .id = 3,
                .name = "เมาส์เกมมิ่ง RGB",
                .price = 2500.00,
                .category = "อุปกรณ์เสริม",
                .in_stock = false,
                .description = "เมาส์เกมมิ่งไฟ RGB ปรับ DPI ได้",
            },
        },
        .pagination = .{
            .page = page,
            .limit = limit,
            .total = 3,
            .has_next = false,
        },
        .filters = .{
            .category = category,
        },
    };

    try res.json(products_data);
}

fn handleSearch(req: *const kamari.Request, res: *kamari.Response) !void {
    // ตัวอย่างการค้นหาด้วย query parameters
    const query = req.query.get("q") orelse "";
    const search_type = req.query.get("type") orelse "all";

    if (query.len == 0) {
        const ErrorResponse = struct {
            @"error": []const u8,
            code: []const u8,
            suggestion: []const u8,
        };
        const error_data = ErrorResponse{
            .@"error" = "❌ จำเป็นต้องระบุคำค้นหา",
            .code = "MISSING_QUERY",
            .suggestion = "ใช้ ?q=คำค้นหา เพื่อค้นหา",
        };
        _ = res.status(400);
        try res.json(error_data);
        return;
    }

    const SearchResult = struct {
        id: u32,
        title: []const u8,
        type: []const u8,
        relevance: f32,
    };

    const SearchResponse = struct {
        query: []const u8,
        search_type: []const u8,
        results: []const SearchResult,
        total_found: u32,
        search_time_ms: f32,
    };

    const search_data = SearchResponse{
        .query = query,
        .search_type = search_type,
        .results = &[_]SearchResult{
            SearchResult{
                .id = 1,
                .title = "คู่มือการใช้งาน Kamari-Zig Framework",
                .type = "documentation",
                .relevance = 0.95,
            },
            SearchResult{
                .id = 2,
                .title = "ตัวอย่างการสร้าง REST API ด้วย Zig",
                .type = "tutorial",
                .relevance = 0.87,
            },
            SearchResult{
                .id = 3,
                .title = "เทคนิคการปรับแต่งประสิทธิภาพ",
                .type = "guide",
                .relevance = 0.73,
            },
        },
        .total_found = 3,
        .search_time_ms = 2.5,
    };

    try res.json(search_data);
}
