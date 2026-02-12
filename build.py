import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).parent
SRC_DIR = PROJECT_ROOT / "src"
CFG_FILE = PROJECT_ROOT / "nes.cfg"
OUTPUT_ROM = PROJECT_ROOT / "main.nes"


def run_command(command: list[str]) -> None:
    """Run a shell command and stop on failure."""
    print(">>", " ".join(command))
    result = subprocess.run(command)

    if result.returncode != 0:
        print("\nBuild failed.")
        sys.exit(result.returncode)


def compile_sources() -> list[Path]:
    """Compile all .asm files in src/ and return object file paths."""
    asm_files = sorted(SRC_DIR.glob("*.asm"))

    if not asm_files:
        print("No .asm files found in src/")
        sys.exit(1)

    object_files = []

    for asm in asm_files:
        obj = asm.with_suffix(".o")
        object_files.append(obj)

        run_command([
            "ca65",
            str(asm),
            "-o",
            str(obj)
        ])

    return object_files


def link_objects(object_files: list[Path]) -> None:
    """Link object files into final NES ROM."""
    if not CFG_FILE.exists():
        print("Missing nes.cfg")
        sys.exit(1)

    run_command([
        "ld65",
        *map(str, object_files),
        "-C",
        str(CFG_FILE),
        "-o",
        str(OUTPUT_ROM)
    ])

    print(f"\nBuild successful: {OUTPUT_ROM.name}")


def main():
    print("=== NES Build Script ===\n")

    object_files = compile_sources()
    link_objects(object_files)


if __name__ == "__main__":
    main()
