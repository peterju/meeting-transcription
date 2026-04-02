# Project Rules

## File Encoding & Language Rules

1. **`.cmd` scripts**: Must use **Chinese text**, **Big5 (CP950) encoding**, and **CRLF** line endings.
2. **`.ps1` scripts**: Must use **English-only comments**, **UTF-8 encoding** (without BOM), and **CRLF** line endings.
3. **`settings.json`**: Must be saved in **UTF-8** encoding.

## Important Notes

- Never add Chinese characters or non-ASCII characters to `.ps1` file comments.
- When editing `.cmd` files, ensure the file is written with Big5 encoding. Use PowerShell: `[IO.File]::WriteAllText("path", $content, [System.Text.Encoding]::GetEncoding(950))`
- The CLI menu (`menuCli.cmd`) sets `chcp 950` before launching `.ps1` scripts; each `.ps1` script must override this with `chcp 65001` for correct UTF-8 console output.
