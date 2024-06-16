# WSLSel

A little companion app to my WSLGit fork (https://github.com/arbmind/wslgit `feature/best_git`).

While my WSLGit fork will launch the git version based on the git or work tree directory location.
This will launch the appropriate bash shell on the same analysis.

Pathes to `\\wsl$\` or `\\wsl.localhost\` will be opened using WSL terminal to the correct distribution.
Other pathes use the `env:WSLGIT_WIN_BASH` or replace `git.exe` with `bash.exe` in `env:WSLGIT_WIN_GIT` or if none is set fall back to regular `cmd`.

## Scenario

I use a lot of Git repositories for my projects. Many are of them are multi platform.
To manage these repositories I use [Fork](https://git-fork.com/) for repositories that are stored on Windows local pathes and on WSL.
WSLGit allows fork to invoke the correct Git version for Windows or WSL. This avoids slow runs and line ending hassles.
The `bashsel` tool is used for the `Open in console` feature of Fork to open the best shell environment for the repository.

## Build

1. Dowload and Unpack [Zig 0.13.0](https://ziglang.org/download/#release-0.13.0).
2. Add `zig.exe` to your path environment.
3. Run `zig build --release=fast`

## Manual Install

1. Follow the setup of WSLGit project.
2. Add `bashsel.exe` to the `cmd` folder.
3. Change symlinks in `bin` folder to point to `bashsel.exe`.
   ```cmd
   cd wslgit\bin
   del bash.exe
   del sh.exe
   mklink bash.exe ..\cmd\bashsel.exe
   mklink sh.exe ..\cmd\bashsel.exe
   cd ..\cmd
   del bash.exe
   mklink bash.exe bashsel.exe
   ```

❤️😎 ... Enjoy!
