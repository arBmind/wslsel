const std = @import("std");
const wslsel = @import("wslsel");

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

    const working_dir = try wslsel.selectGitWorkingDirectory(gpa, curr_dir, env_map.get("GIT_WORK_TREE") orelse &.{}, args);
    defer gpa.free(working_dir);

    const classification = wslsel.classifyDirectory(working_dir);
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
