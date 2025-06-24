# Kamari-Zig

เฟรมเวิร์ก HTTP เว็บที่รวดเร็วและเบาสำหรับ Zig ได้รับแรงบันดาลใจจากเฟรมเวิร์กเว็บสมัยใหม่อย่าง Express.js และ Fastify

## คุณสมบัติ

- **🚀 HTTP Server ที่รวดเร็ว**: สร้างด้วย Zig standard library โดยไม่มี external dependencies
- **🛣️ ระบบ Routing ยืดหยุ่น**: รองรับ dynamic routes ด้วยพารามิเตอร์ (`:id`, `:name` เป็นต้น)
- **🔧 ระบบ Middleware**: Middleware ที่สามารถประกอบกันได้สำหรับ cross-cutting concerns (CORS, logging, authentication เป็นต้น)
- **📦 รองรับ JSON**: การแปลง JSON และสร้าง response ในตัว
- **🔒 Type Safety**: ความปลอดภัยประเภทอย่างเต็มรูปแบบด้วยระบบประเภทที่ทรงพลังของ Zig
- **⚡ Zero Dependencies**: ใช้เฉพาะ Zig standard library เพื่อประสิทธิภาพสูงสุด
- **🎯 API ง่าย**: API ที่ใช้งานง่ายได้รับแรงบันดาลใจจากเฟรมเวิร์กเว็บยอดนิยม

## การติดตั้ง

### ใช้ Zig Package Manager (แนะนำ)

เพิ่ม kamari-zig ใน `build.zig.zon` ของคุณ:

```zon
.{
    .name = "your-project",
    .version = "0.1.0",
    .minimum_zig_version = "0.14.1",
    .dependencies = .{
        .kamari = .{
            .url = "https://github.com/jamesatomc/kamari-zig/archive/main.tar.gz",
            // Hash จะถูกคำนวณอัตโนมัติเมื่อคุณรัน `zig build`
        },
    },
}
```

จากนั้นใน `build.zig` ของคุณ:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // รับ dependency ของ kamari
    const kamari_dep = b.dependency("kamari", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "your-project",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // เพิ่ม kamari module
    exe.root_module.addImport("kamari", kamari_dep.module("kamari"));
    
    b.installArtifact(exe);
}
```

### การติดตั้งแบบ Manual

Clone repository และรวมไว้ในโปรเจกต์ของคุณ:

```bash
git clone https://github.com/jamesatomc/kamari-zig.git
```

หรือดาวน์โหลด release ล่าสุดจากหน้า GitHub releases

## เริ่มต้นใช้งาน

```zig
const std = @import("std");
const kamari = @import("kamari");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // สร้าง server และ router
    var server = kamari.Server.init(allocator);
    defer server.deinit();

    var router = kamari.Router.init(allocator);
    defer router.deinit();

    // เพิ่ม middleware
    try router.use(kamari.middleware.cors);
    try router.use(kamari.middleware.logger);

    // กำหนด routes
    try router.get("/", handleHome);
    try router.get("/users/:id", handleUser);
    try router.post("/users", handleCreateUser);

    // เริ่ม server
    std.debug.print("🚀 เซิร์ฟเวอร์กำลังเริ่มต้นที่ http://127.0.0.1:8080\n", .{});
    try server.listen("127.0.0.1", 8080, &router);
}

fn handleHome(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req;
    const data = .{ .message = "สวัสดี, Kamari-Zig!" };
    try res.json(data);
}

fn handleUser(req: *const kamari.Request, res: *kamari.Response) !void {
    const user_id = req.params.get("id") orelse "ไม่ทราบ";
    const data = .{ .id = user_id, .name = "ชื่อผู้ใช้" };
    try res.json(data);
}

fn handleCreateUser(req: *const kamari.Request, res: *kamari.Response) !void {
    // จัดการข้อมูล POST จาก req.body
    const data = .{ .message = "สร้างผู้ใช้แล้ว", .id = 123 };
    _ = res.status(201);
    try res.json(data);
}
```

## เอกสาร API

### Server

สร้างและเริ่ม HTTP server:

```zig
var server = kamari.Server.init(allocator);
defer server.deinit();

// เริ่ม server ที่ host และ port ที่กำหนด
try server.listen("127.0.0.1", 8080, &router);
```

### Router

สร้างและกำหนดค่า routes:

```zig
var router = kamari.Router.init(allocator);
defer router.deinit();

// HTTP methods
try router.get("/path", handler);
try router.post("/path", handler);
try router.put("/path", handler);
try router.delete("/path", handler);

// Dynamic routes ด้วยพารามิเตอร์
try router.get("/users/:id", handler);
try router.get("/posts/:id/comments/:comment_id", handler);

// เพิ่ม middleware ให้กับทุก routes
try router.use(middleware_function);
```

### Request

เข้าถึงข้อมูล request ใน handlers ของคุณ:

```zig
fn handler(req: *const kamari.Request, res: *kamari.Response) !void {
    // HTTP method
    const method = req.method; // kamari.HttpMethod enum

    // Path และ route parameters
    const path = req.path;
    const user_id = req.params.get("id"); // จาก routes อย่าง /users/:id

    // Query parameters (?search=value&limit=10)
    const search = req.query.get("search");
    const limit = req.query.get("limit");

    // Request headers
    const content_type = req.headers.get("content-type");
    const user_agent = req.headers.get("user-agent");

    // Request body (สำหรับ POST/PUT requests)
    if (req.body) |body| {
        // ประมวลผล request body เป็น string
        std.debug.print("Request body: {s}\n", .{body});
    }
}
```

### Response

ส่ง responses ไปยัง clients:

```zig
fn handler(req: *const kamari.Request, res: *kamari.Response) !void {
    _ = req; // ระงับคำเตือน unused parameter

    // JSON response (ใช้บ่อยที่สุด)
    const data = .{ 
        .message = "สวัสดี, โลก!", 
        .status = "สำเร็จ",
        .timestamp = std.time.timestamp(),
    };
    try res.json(data);

    // Plain text response
    try res.text("สวัสดี, โลก!");

    // HTML response
    try res.html("<h1>สวัสดี, โลก!</h1>");

    // Custom status code พร้อม JSON
    _ = res.status(201); // Created
    const created_data = .{ .id = 123, .message = "สร้าง Resource แล้ว" };
    try res.json(created_data);

    // Custom headers
    _ = try res.header("X-Custom-Header", "custom-value");
    _ = try res.header("Cache-Control", "no-cache");
    try res.text("Response พร้อม custom headers");

    // Error responses
    _ = res.status(404);
    try res.json(.{ .error = "ไม่พบ", .code = 404 });
}
```

## ตัวอย่าง

ตรวจสอบไดเรกทอรี `examples/` สำหรับตัวอย่างที่ครอบคลุม:

- `examples/basic_server.zig` - เซิร์ฟเวอร์ที่มีคุณสมบัติครบครันพร้อม CRUD operations, middleware และ error handling
- `examples/simple_server.zig` - เซิร์ฟเวอร์ hello-world แบบมินิมอล

### รันตัวอย่าง

```bash
# รันตัวอย่างพื้นฐาน (แนะนำ)
zig build run

# หรือรันตัวอย่างเฉพาะ
zig build run-basic
zig build run-simple
```

## การ Build และ Testing

```bash
# Build library
zig build

# รัน tests ทั้งหมด
zig build test

# รัน example server
zig build run

# Build ในโหมด release สำหรับ production
zig build -Doptimize=ReleaseFast

# ตรวจสอบ compilation errors
zig build check
```

## ความต้องการระบบ

- **Zig**: เวอร์ชัน 0.14.1 หรือใหม่กว่า
- **แพลตฟอร์ม**: Cross-platform (Windows, macOS, Linux)
- **หน่วยความจำ**: ใช้หน่วยความจำน้อย

## การมีส่วนร่วม

เรายินดีรับการมีส่วนร่วม! วิธีที่คุณสามารถช่วยได้:

### เริ่มต้น
1. Fork repository
2. สร้าง feature branch: `git checkout -b feature/amazing-feature`
3. ทำการเปลี่ยนแปลง
4. เพิ่ม tests สำหรับฟังก์ชันใหม่
5. รัน test suite: `zig build test`
6. Commit การเปลี่ยนแปลง: `git commit -m 'Add amazing feature'`
7. Push ไป branch: `git push origin feature/amazing-feature`
8. เปิด Pull Request

### แนวทางการพัฒนา
- ปฏิบัติตาม Zig style conventions
- เพิ่ม tests สำหรับฟีเจอร์ใหม่
- อัปเดตเอกสารตามความจำเป็น
- รักษา commits ให้มีการโฟกัสและเป็น atomic
- เขียน commit messages ที่ชัดเจน

## ใบอนุญาต

โปรเจกต์นี้ได้รับใบอนุญาตภายใต้ MIT License - ดูไฟล์ [LICENSE](LICENSE) สำหรับรายละเอียด

## ชุมชนและการสนับสนุน

- **GitHub Issues**: [รายงานบั๊กหรือขอฟีเจอร์](https://github.com/jamesatomc/kamari-zig/issues)
- **Discussions**: [การสนทนาและคำถามของชุมชน](https://github.com/jamesatomc/kamari-zig/discussions)
- **Zig Discord**: ค้นหาเราในชุมชน Discord ของ Zig

## ขอบคุณ

Kamari-Zig ถูกสร้างด้วย ❤️ ใน Zig
