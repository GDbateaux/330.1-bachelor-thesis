# Carl: Cellular Automata Rule Language

Carl is a domain-specific language for defining cellular automata. It compiles .carl files into executables that simulate and visualize the automaton using Raylib.

## Features

- Custom DSL for cellular automata
- N-dimensional automata
- Moore, Von Neumann or hexagonal neighborhoods
- Executable generation
- Real-time visualization with Raylib

## Installation

### Prerequisites

- [Swift](https://www.swift.org/install/) installed

### Build from Source

```bash
git clone https://github.com/GDbateaux/330.1-bachelor-thesis.git
cd 330.1-bachelor-thesis
```

## Usage

Write a cellular automaton in a .carl file, then compile it:

```bash
swift run Carl file-path.carl -o file-path-output
./game-of-life
```

### Command-line options

| Option                | Description                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------------- |
| `<source-file>`       | Path to the Carl source file (`.carl`).                                                      |
| `-o`, `--output`      | Output executable path.                                                                      |
| `-g`, `--grid-length` | Grid size along each dimension. Defaults to `200` for 2D automata and `20` for 3D or higher. |
| `--steps-per-frame`   | Number of simulation steps between texture updates (2D only). Defaults to `1`.               |
| `--clean`             | Clean the build cache before recompiling.                                                    |

## Language documentation

See [docs/DSL_design.md](docs/DSL_design.md) for the language specification, EBNF grammar and examples.

## Examples

### Game of Life

```carl
automaton GameOfLife {
    world {
        states { Dead, Alive }
        neighborhood: Moore(1)
        dimension: 2
    }
    initial {
        Dead: 0.7
        Alive: 0.3
    }
    rules {
        Dead -> Alive when count_neighbors(Alive) == 3
        Alive -> Dead when count_neighbors(Alive) < 2 or count_neighbors(Alive) > 3
    }
}
```

More examples are available in the [examples](examples) directory

## Profiling with Tracy

This branch enables profiling via [Tracy](https://github.com/wolfpld/tracy). The profiling integration with tracy follows the blog at https://compositorapp.com/blog/2026-02-07/Tracy/

### Building the profiler

[CMake](https://cmake.org/download/) is required.

```bash
cd tracy
cmake -S profiler -B profiler/build -DCMAKE_BUILD_TYPE=Release
cmake --build profiler/build --config Release
```

This produces `tracy-profiler.exe` in `tracy/profiler/build/Release/`.

### Running a profiling session

1. Start `tracy-profiler.exe`
2. Build and run Carl:
   ```bash
   swift run Carl examples/game-of-life.carl -o game-of-life.exe
   game-of-life.exe
   ```
3. Click "Connect" in the profiler.

## Project Structure

```
.
├──.github/workflows/  
│  └── compile-carl.yml           # CI: build & test on ubuntu/macos/windows  
├──docs/  
│  └── DSL_design.md              # Language specification + EBNF grammar  
├──examples/                      # Example .carl programs  
├──Sources/  
│  ├── Carl/                      # Carl compiler  
│  │   ├── Carl.swift             # CLI entry point 
│  │   ├── CodeGen/               # Swift code generation  
│  │   │   ├── NDGrid.swift       # N-dimensional grid
│  │   │   └── SwiftGenerator.swift # AST → Swift source  
│  │   ├── Compiler.swift         # Compilation pipeline orchestrator  
│  │   ├── Parser/  
│  │   │   ├── AST.swift          # AST node definitions  
│  │   │   ├── Error.swift        # Compiler error types  
│  │   │   ├── Lexer.swift        # Lexical analysis  
│  │   │   ├── Parser.swift       # Syntactic analysis
│  │   │   └── Token.swift        # Token definitions  
│  │   └── Semantic/  
│  │       └── SemanticAnalyzer.swift # Semantic analysis  
│  └── CRaylib/                   # Raylib C
├──Tests/                         # Compiler unit tests
├──Package.resolved
├──Package.swift
├──README.md
└── .gitignore  
```

Built with assistance from Opencode's Big Pickle model.
