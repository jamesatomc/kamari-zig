const std = @import("std");

pub const JsonError = error{
    InvalidJson,
    MissingField,
    InvalidType,
};

pub fn parseJson(comptime T: type, allocator: std.mem.Allocator, json_string: []const u8) !T {
    var parser = std.json.Parser.init(allocator, false);
    defer parser.deinit();

    var tree = try parser.parse(json_string);
    defer tree.deinit();

    return try std.json.parseFromValueLeaky(T, allocator, tree.root, .{});
}

pub fn stringifyJson(value: anytype, allocator: std.mem.Allocator) ![]u8 {
    var string = std.ArrayList(u8).init(allocator);
    try std.json.stringify(value, .{}, string.writer());
    return string.toOwnedSlice();
}

// URL encoding/decoding utilities
pub fn urlEncode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    for (input) |char| {
        if (std.ascii.isAlphanumeric(char) or char == '-' or char == '_' or char == '.' or char == '~') {
            try result.append(char);
        } else {
            try result.writer().print("%{X:0>2}", .{char});
        }
    }

    return result.toOwnedSlice();
}

pub fn urlDecode(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var i: usize = 0;
    while (i < input.len) {
        if (input[i] == '%' and i + 2 < input.len) {
            const hex_string = input[i + 1 .. i + 3];
            const decoded_char = std.fmt.parseInt(u8, hex_string, 16) catch {
                try result.append(input[i]);
                i += 1;
                continue;
            };
            try result.append(decoded_char);
            i += 3;
        } else if (input[i] == '+') {
            try result.append(' ');
            i += 1;
        } else {
            try result.append(input[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice();
}
