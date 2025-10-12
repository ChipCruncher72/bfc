# `bfc`: The Brainfuck Compiler Toolchain

> [!WARNING]
> This project is in pre-release, expect bugs and/or an unfinished product if you decide to download this

---

## Download
To download the `bfc` toolchain, you must first have [Zig 0.15.x](https://ziglang.org/download/#:~:text=52MiB-,0.15.2,-2025%2D10%2D11) installed

> [!NOTE]
> master or version prior to 0.15 may work, though it is recommended to use a 0.15 version of the compiler for ensured compatibily

After you have installed Zig, download the repository and cd into it. Then run
```sh
zig build
# Optional compiler flags
zig build -Doptimize=ReleaseFast
```
You should be able to find the executable under `./zig-out/bin` named "bfc"

## Roadmap
This toolchain is highly incomplete, here is a incomprehensive list of things left to do:
- [x] Interpret files
- [ ] Allow io to files
- [x] Add a `-h` and `--help` compiler flag
- [ ] Implement trans-compilation
    - [ ] Zig
    - [ ] C
    - [ ] C++
    - [ ] Rust
- [ ] Compilation to an executable
