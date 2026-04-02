# Configurable Backends

Allow users to choose which coding agent CLI runs inside the pi.nvim terminal split.

## Config Surface

```lua
require("pi").setup({
  backend = "opencode",           -- "pi" (default) | "opencode" | custom table
  backend_opts = {                -- optional overrides for the chosen preset
    bin = "/custom/path/opencode",
    extra_args = { "--model", "anthropic/claude-sonnet" },
  },
  split = { position = "right", width = 0.35 },
  keymaps = { ask = "<leader>ap", toggle = "<leader>pp", yank = "gy" },
})
```

`backend` accepts a string (preset name) or a full backend table.
`backend_opts` merges into the resolved preset — only meaningful when `backend` is a string.

## Backend Table Shape

Every backend resolves to this structure:

```lua
{
  bin = "opencode",       -- executable name or path
  extra_args = {},        -- persistent extra CLI flags
  build_cmd = function(bin, extra_args, prompt)
    -- Returns a list of strings passed to termopen().
    -- `prompt` may be nil (e.g. toggle with no question).
  end,
  format_prompt = function(ctx, question)
    -- Returns the formatted prompt string.
    -- `ctx` has: file, start_line (optional), end_line (optional).
  end,
}
```

## Presets

### pi

```lua
{
  bin = "pi",
  extra_args = {},
  build_cmd = function(bin, extra_args, prompt)
    local cmd = { bin }
    for _, a in ipairs(extra_args) do cmd[#cmd + 1] = a end
    if prompt then cmd[#cmd + 1] = prompt end
    return cmd
  end,
  format_prompt = function(ctx, question)
    if ctx.start_line then
      return string.format("Refer `%s` lines %d-%d. %s", ctx.file, ctx.start_line, ctx.end_line, question)
    end
    return string.format("Refer `%s`. %s", ctx.file, question)
  end,
}
```

### opencode

```lua
{
  bin = "opencode",
  extra_args = {},
  build_cmd = function(bin, extra_args, prompt)
    local cmd = { bin }
    for _, a in ipairs(extra_args) do cmd[#cmd + 1] = a end
    if prompt then
      cmd[#cmd + 1] = "--prompt"
      cmd[#cmd + 1] = prompt
    end
    return cmd
  end,
  format_prompt = function(ctx, question)
    if ctx.start_line then
      return string.format("Refer @%s lines %d-%d. %s", ctx.file, ctx.start_line, ctx.end_line, question)
    end
    return string.format("Refer @%s. %s", ctx.file, question)
  end,
}
```

### Custom

Users pass a table directly:

```lua
backend = {
  bin = "my-agent",
  build_cmd = function(bin, extra_args, prompt)
    return { bin, "--ask", prompt }
  end,
  format_prompt = function(ctx, question)
    return string.format("Look at %s. %s", ctx.file, question)
  end,
}
```

## Resolution Logic (`config.get_backend()`)

1. If `backend` is a table — use it directly (merge `backend_opts` on top).
2. If `backend` is a string — look up the preset, merge `backend_opts` on top.
3. Error on unknown preset name.

## File Changes

| File | Change |
|---|---|
| `lua/pi/backends.lua` | **New** — preset definitions and `resolve(name_or_table, opts)` |
| `lua/pi/config.lua` | Replace `pi = { bin, extra_args }` with `backend` / `backend_opts` defaults; add `get_backend()` |
| `lua/pi/context.lua` | `format_prompt` takes backend as first arg, delegates to `backend.format_prompt` |
| `lua/pi/ui.lua` | `open()` uses `backend.build_cmd` instead of hand-building the command |
| `lua/pi/init.lua` | Thread `config.get_backend()` through to context and ui calls |

## Backwards Compatibility

The old `pi = { bin, extra_args }` key is no longer recognised. Since this plugin is pre-1.0 and has few users, a clean break is acceptable. The README will document the new config shape.
