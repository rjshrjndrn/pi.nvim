--- Manages the Neovim integration skill for pi agent.
---
--- Writes a skill file to the project's .pi/agent/skills/ directory
--- that teaches pi about available RPC commands when running inside Neovim.

local M = {}

local SKILL_DIR_NAME = "nvim-integration"
local GLOBAL_SKILLS_DIR = vim.fn.expand("~/.pi/agent/skills/" .. SKILL_DIR_NAME)
local SKILL_FILE = GLOBAL_SKILLS_DIR .. "/SKILL.md"

local SKILL_CONTENT = [[---
name: nvim-integration
description: >
  Control parent Neovim when running inside a Neovim terminal.
  Open files, preview code, read/write buffers directly, show diffs.
  Triggered automatically when $NVIM is set (always true when launched from pi.nvim).
license: MIT
metadata:
  author: pi.nvim
  version: "1.0"
---

# Neovim Buffer Integration

You are running inside a Neovim terminal. The `$NVIM` env var points to the parent Neovim's Unix socket. You can control the editor directly.

## Available Commands

All commands use this pattern:
```bash
nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.FUNCTION(ARGS)')"
```

### 1. Open file at line (in code window, not terminal)
```bash
nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.open_at(\"path/to/file.lua\", 42)')"
```

### 2. Read buffer lines (includes unsaved edits!)
```bash
nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.buf_lines(\"path/to/file.lua\", 10, 25)')"
```
- Returns actual buffer content, not disk content
- Omit start/end to get all lines
- Useful to see user's unsaved work

### 3. Write lines to buffer (no disk write, user can undo)
```bash
nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.buf_set_lines(\"path/to/file.lua\", 10, 15, {\"line1\", \"line2\"})')"
```
- Buffer must be open (use open_at first if needed)
- Creates undo point — user can `u` to revert
- Does NOT save to disk — user decides when to `:w`

### 4. Preview lines in floating window
```bash
nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.preview(\"path/to/file.lua\", 10, 25, \" Preview \")')"
```
- Shows code in centered float with syntax highlighting
- User closes with `q` or `Esc`

### 5. Show diff (current buffer vs proposed changes)
```bash
nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.show_diff(\"path/to/file.lua\", {\"new line 1\", \"new line 2\"})')"
```
- Opens side-by-side diff in Neovim

### 6. Get editor state (current file, cursor, modified status)
```bash
nvim --server "$NVIM" --remote-expr "luaeval('PiRpc.editor_state()')"
```
- Returns: file, line, col, total_lines, modified, filetype

## When to Use

- **Reviewing code**: Use `preview()` to show the function being discussed in a float
- **Before editing**: Use `buf_lines()` to read current buffer state (may have unsaved changes)
- **Applying changes**: Use `buf_set_lines()` to write directly to buffer — faster than file write, user can undo
- **Showing proposals**: Use `show_diff()` to let user see before/after
- **Navigation**: Use `open_at()` to jump user to relevant code

## Important Notes

- Always use **absolute paths** or paths relative to project root
- `buf_lines()` reads **buffer content** (unsaved edits included), not disk
- `buf_set_lines()` does NOT save to disk — user must `:w` explicitly
- The `read` and `edit` tools still work on **files on disk** — use those for persistent changes
- Use RPC for **interactive** workflows (preview, navigate, propose changes)
]]

--- Install skill to ~/.pi/agent/skills/ so pi agent always knows about RPC.
--- Idempotent — only writes if content changed.
function M.ensure()
	-- Create directory
	vim.fn.mkdir(GLOBAL_SKILLS_DIR, "p")

	-- Check if content changed
	local f = io.open(SKILL_FILE, "r")
	if f then
		local existing = f:read("*a")
		f:close()
		if existing == SKILL_CONTENT then
			return -- already up to date
		end
	end

	-- Write skill file
	f = io.open(SKILL_FILE, "w")
	if f then
		f:write(SKILL_CONTENT)
		f:close()
	end
end

return M
