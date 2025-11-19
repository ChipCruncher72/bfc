# `bfc`: Brainfuck Compiler\* and Interpreter
<sup>\*Cannot compile any code as of yet</sup>\
<sup>`bfc` stands for BrainFuck Code tool (The tool is silent)</sup>

> [!IMPORTANT]
> I have moved this repository to [Codeberg](https://codeberg.org/ChipCruncher72/bfc) and archived it\
> I should also advise you not to contact me through GitHub as I am likely to be way less active and may not reply, or even see your message in the first place\
> My other repositories will be archived in due time as well

---

> [!WARNING]
> This project is in pre-release, expect bugs and/or an unfinished product if you decide to download this

---

## Download
To download `bfc`, you must first have [Zig 0.15.x](https://ziglang.org/download/#:~:text=52MiB-,0.15.2,-2025%2D10%2D11) installed

> [!NOTE]
> master or versions prior to 0.15 may work, though it is recommended to use a 0.15 version of the compiler for ensured compatibily

After you have installed Zig, download the repository and cd into it. Then run
```sh
zig build
# Optional compiler flags
zig build -Doptimize=ReleaseFast
```
You should now be able to find the executable under `./zig-out/bin` named "bfc"
```
# Run this to get help for the compiler!
bfc -h
```

## Tasks
The compiler/interpreter is highly incomplete, here is a incomprehensive list of things left to do:
- [x] Interpret files
- [x] Allow io to files (interpreter only)
- [x] Add a `-h` and `--help` compiler flag
- [ ] Implement trans-compilation
    - [ ] Zig
    - [x] C
    - [x] C++
    - [ ] Rust
    - [ ] Python
    - [ ] Javascript
    - [ ] Golang
- [ ] Compilation to an executable
- [ ] Build system
- [x] REPL
