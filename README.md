# WSLSel

A company app to my WSLGit fork (https://github.com/arbmind/wslgit `feature/best_git`).

While my WSLGit fork will launch the git version based on the git or work tree directory location.
This will launch the appropriate bash shell on the same analysis.

Pathes to `\\wsl$\` or `\\wsl.localhost\` will be opened using WSL terminal to the correct distribution.
Other pathes use the `env:WSLGIT_WIN_BASH` or replace `git.exe` with `bash.exe` in `env:WSLGIT_WIN_GIT` or if none is set fall back to regular `cmd`.

## Build

1. Dowload and Unpack [Zig 0.13.0](https://ziglang.org/download/#release-0.13.0).
2. Add `zig.exe` to your path environment.
3. Run `build_exe.bat`

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
