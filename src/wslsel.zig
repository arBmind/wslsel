const std = @import("std");

fn combinePath(gpa: std.mem.Allocator, base_dir: []u8, rel_dir: []const u8) ![]u8 {
    defer gpa.free(base_dir);
    return std.fs.path.resolve(gpa, &.{ base_dir, rel_dir });
}

pub fn selectGitWorkingDirectory(gpa: std.mem.Allocator, curr_dir: []const u8, work_tree_in: []const u8, args: []const [:0]const u8) ![]u8 {
    var result_dir = try gpa.dupe(u8, curr_dir);
    errdefer gpa.free(result_dir);
    var work_tree = work_tree_in;
    // note: parse enough git arguments to extract git base directory or work tree path
    var i: u32 = 0;
    while (i < args.len) {
        const arg = args[i];
        i += 1;
        if (std.mem.eql(u8, arg, "-c")) {
            i += 1; // ignore value
        } else if (std.mem.eql(u8, arg, "-C") and i < args.len) {
            result_dir = try combinePath(gpa, result_dir, args[i]);
            i += 1; // used
        } else if (std.mem.startsWith(u8, arg, "--work-tree=")) {
            work_tree = arg[12..];
        } else if (!std.mem.startsWith(u8, arg, "-")) {
            break;
        }
    }

    if (work_tree.len > 0) {
        result_dir = try combinePath(gpa, result_dir, work_tree);
    }
    return result_dir;
}

test selectGitWorkingDirectory {
    const gpa = std.testing.allocator;

    {
        const actual = try selectGitWorkingDirectory(gpa, "C:\\projects\\foo", &.{}, &.{});
        defer gpa.free(actual);
        try std.testing.expectEqualDeep("C:\\projects\\foo", actual);
    }
    {
        const actual = try selectGitWorkingDirectory(gpa, "C:\\project\\foo", "..\\develop", &.{});
        defer gpa.free(actual);
        try std.testing.expectEqualDeep("C:\\project\\develop", actual);
    }
    {
        const actual = try selectGitWorkingDirectory(gpa, "C:\\project\\foo", "..\\ignore1", &.{
            "-c",
            "..\\ignore2",
            "--work-tree=..\\develop",
            "push",
        });
        defer gpa.free(actual);
        try std.testing.expectEqualDeep("C:\\project\\develop", actual);
    }
}

pub const Classification = union(enum) {
    windows,
    wsl_distro: []const u8,
};
/// Takes windows path and checks if it's located on a wsl distro
pub fn classifyDirectory(dir: []const u8) Classification {
    const UNC_SERVER_WSL = "\\\\wsl$\\";
    const UNC_SERVER_WSL_LOCALHOST = "\\\\wsl.localhost\\";

    const remaining = blk: {
        if (std.mem.startsWith(u8, dir, UNC_SERVER_WSL)) {
            break :blk dir[UNC_SERVER_WSL.len..dir.len];
        } else if (std.mem.startsWith(u8, dir, UNC_SERVER_WSL_LOCALHOST)) {
            break :blk dir[UNC_SERVER_WSL_LOCALHOST.len..dir.len];
        } else {
            return Classification.windows;
        }
    };
    const index = std.mem.indexOf(u8, remaining, "\\") orelse remaining.len;
    return Classification{ .wsl_distro = remaining[0..index] };
}

test classifyDirectory {
    try std.testing.expectEqualDeep(Classification.windows, classifyDirectory("C:\\Users\\foo\\projects\\bashsel"));
    try std.testing.expectEqualDeep(Classification{ .wsl_distro = "arch" }, classifyDirectory("\\\\wsl$\\arch\\home\\foo\\projects\\bashsel"));
    try std.testing.expectEqualDeep(Classification{ .wsl_distro = "arch" }, classifyDirectory("\\\\wsl.localhost\\arch\\home\\foo\\projects\\bashsel"));
}
