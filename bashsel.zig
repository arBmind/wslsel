const std = @import("std");

fn combinePath(gpa: std.mem.Allocator, base_dir: []u8, rel_dir: []const u8) ![]u8 {
    defer gpa.free(base_dir);
    return std.fs.path.resolve(gpa, &.{ base_dir, rel_dir });
}

fn selectGitWorkingDirectory(gpa: std.mem.Allocator, curr_dir: []const u8, work_tree_in: []const u8, args: []const [:0]const u8) ![]u8 {
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

const Classification = union(enum) {
    windows,
    wsl_distro: []const u8,
};
/// Takes windows path and checks if it's located on a wsl distro
fn classifyDirectory(dir: []const u8) Classification {
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

fn selectWindowsBash(gpa: std.mem.Allocator, env_map: *std.process.EnvMap) ![]const u8 {
    const WSLGIT_WIN_BASH = "WSLGIT_WIN_BASH";
    const WSLGIT_WIN_GIT = "WSLGIT_WIN_GIT";
    const GIT_EXE = "git.exe";
    const BASH_EXE = "bash.exe";

    if (env_map.get(WSLGIT_WIN_BASH)) |bash_path| {
        return bash_path;
    }
    if (env_map.get(WSLGIT_WIN_GIT)) |git_path| {
        if (std.mem.endsWith(u8, git_path, GIT_EXE)) {
            const bash_path = try std.mem.concat(gpa, u8, &.{ git_path[0 .. git_path.len - GIT_EXE.len], BASH_EXE });
            defer gpa.free(bash_path);
            // note: store in env_map with it's allocator and return slice to that instance to avoid use after free
            try env_map.put(WSLGIT_WIN_BASH, bash_path);
            if (env_map.get(WSLGIT_WIN_BASH)) |bash_path2| {
                return bash_path2;
            }
        }
    }
    return "cmd";
}

test selectWindowsBash {
    const gpa = std.testing.allocator;
    {
        var env_map = std.process.EnvMap.init(gpa);
        defer env_map.deinit();
        try std.testing.expectEqualDeep("cmd", selectWindowsBash(gpa, &env_map));
    }
    {
        var env_map = std.process.EnvMap.init(gpa);
        defer env_map.deinit();
        try env_map.put("WSLGIT_WIN_BASH", "bash");
        try std.testing.expectEqualDeep("bash", selectWindowsBash(gpa, &env_map));
    }
    {
        var env_map = std.process.EnvMap.init(gpa);
        defer env_map.deinit();
        try env_map.put("WSLGIT_WIN_GIT", "C:\\git\\bin\\git.exe");
        try std.testing.expectEqualDeep("C:\\git\\bin\\bash.exe", selectWindowsBash(gpa, &env_map));
    }
}

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    const curr_dir = try std.process.getCwdAlloc(gpa);
    defer gpa.free(curr_dir);

    const all_args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, all_args);
    const args = all_args[1..];

    var env_map = try std.process.getEnvMap(gpa);
    defer env_map.deinit();

    const working_dir = try selectGitWorkingDirectory(gpa, curr_dir, env_map.get("GIT_WORK_TREE") orelse &.{}, args);
    defer gpa.free(working_dir);

    const classification = classifyDirectory(working_dir);
    const child_args: []const []const u8 = switch (classification) {
        .windows => &.{try selectWindowsBash(gpa, &env_map)},
        .wsl_distro => |distro| &.{ "wsl", "--distribution", distro },
    };

    var child = std.process.Child.init(child_args, gpa);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;
    const term = try child.spawnAndWait();
    _ = switch (term) {
        .Exited => |code| std.process.exit(code),
        else => std.process.abort(),
    };
}
