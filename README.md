# pi.nvim

Neovim plugin that embeds [pi](https://github.com/mariozechner/pi-coding-agent) as a side panel. Ask questions about your code, get help with specific lines, and chat with pi — all without leaving your editor.

## Features

- **Side panel** — Pi's full TUI in a right split
- **Visual selection context** — Select code, ask about it. Pi knows the file and line numbers
- **Follow-up questions** — Send follow-ups to the same pi session from any buffer
- **Toggle** — Show/hide the panel, pi stays alive in the background

## Requirements

- Neovim ≥ 0.9
- [pi](https://github.com/mariozechner/pi-coding-agent) or [opencode](https://github.com/opencode-ai/opencode) installed and available in `$PATH`

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "rjshrjndrn/pi.nvim",
  config = function()
    require("pi").setup()
  end,
}
```

### Local development

```lua
{
  dir = "~/projects/pi.nvim",
  config = function()
    require("pi").setup()
  end,
}
```

## Configuration

```lua
require("pi").setup({
  backend = "pi",        -- "pi" (default) | "opencode" | custom table
  backend_opts = {},     -- override bin or extra_args for the chosen preset
  split = {
    position = "right",  -- panel position
    width = 0.35,        -- 35% of screen width
  },
  keymaps = {
    ask = "<leader>ap",  -- ask pi (normal + visual)
    toggle = "<leader>pp", -- toggle panel visibility
  },
})
```

### Backends

Switch the coding agent that runs inside the panel:

```lua
-- Use opencode instead of pi
require("pi").setup({
  backend = "opencode",
})

-- Override binary path or add extra CLI flags
require("pi").setup({
  backend = "opencode",
  backend_opts = {
    bin = "/usr/local/bin/opencode",
    extra_args = { "--model", "anthropic/claude-sonnet" },
  },
})

-- Fully custom backend
require("pi").setup({
  backend = {
    bin = "my-agent",
    extra_args = {},
    build_cmd = function(bin, extra_args, prompt)
      local cmd = { bin }
      for _, a in ipairs(extra_args) do cmd[#cmd + 1] = a end
      if prompt then cmd[#cmd + 1] = prompt end
      return cmd
    end,
    format_prompt = function(ctx, question)
      return string.format("Refer %s. %s", ctx.file, question)
    end,
  },
})
```

| Preset | How prompt is passed | File reference style |
|--------|---------------------|---------------------|
| `pi` | Positional arg | `` Refer `file.lua` `` |
| `opencode` | `--prompt` flag | `Refer @file.lua` |

## Usage

### Ask about code

1. Select lines visually
2. Press `<leader>ap`
3. Type your question
4. Pi opens in a right split with your question + file context

### Ask about current file

1. Press `<leader>ap` in normal mode (no selection)
2. Type your question
3. Pi knows which file you're in

### Follow-up questions

1. Select new code (or stay in normal mode)
2. Press `<leader>ap` again
3. Your question is sent to the **same pi session**

### Toggle panel

Press `<leader>pp` to show/hide the pi panel. Pi keeps running in the background.

### Commands

| Command | Description |
|---------|-------------|
| `:PiAsk` | Ask pi a question |
| `:PiToggle` | Toggle the side panel |
| `:PiStop` | Kill pi process and close panel |

## How it works

The chosen backend's TUI runs in a Neovim terminal buffer in a right split. When you ask about code, the plugin captures the filename and line numbers, formats a prompt using the backend's style, and sends it to the agent. The agent uses its own tools to access your files directly — no code extraction needed.

## License

MIT
