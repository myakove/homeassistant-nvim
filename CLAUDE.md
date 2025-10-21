# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**homeassistant.nvim** is a Neovim plugin providing Home Assistant integration via LSP. The plugin acts as an LSP client that connects to [homeassistant-lsp](https://github.com/myakove/homeassistant-lsp), which handles the heavy lifting (WebSocket communication, entity caching, completion, diagnostics).

**Key Separation of Concerns:**
- **This plugin (Lua)**: Neovim UI, LSP client setup, user commands, keymaps
- **homeassistant-lsp (TypeScript/Node.js)**: WebSocket API client, entity/service data, completion logic, diagnostics

## Development Commands

### Code Quality

```bash
# Install pre-commit hooks (uses prek wrapper)
prek install

# Run all hooks on all files
prek run

# Format Lua code with StyLua
stylua lua/

# Lint with Luacheck
luacheck lua/
```

**Pre-commit hooks enforce:**
- StyLua formatting (`.stylua.toml`)
- Luacheck linting (`.luacheckrc`)
- Standard checks (trailing whitespace, EOF, YAML validation)

**IMPORTANT:** Never bypass pre-commit hooks with `--no-verify`.

### Testing

```bash
# Manual testing in Neovim
nvim --clean -u test_config.lua  # If test config exists

# Health check (primary testing method)
:checkhealth homeassistant
```

### Debugging

```vim
" In Neovim
:HADebug                    " Show plugin debug info
:messages                   " View log messages
:lua vim.print(require("homeassistant.config").get())  " Inspect config
:LspInfo                    " Check LSP client status
:LspLog                     " View LSP communication logs
```

## Architecture

### Module Structure

```
lua/homeassistant/
├── init.lua              -- Entry point: setup(), command registration, keymap setup
├── config.lua            -- Configuration management with defaults and validation
├── lsp_client.lua        -- LSP client setup using vim.lsp.config/enable/start
├── health.lua            -- :checkhealth integration
├── ui/
│   ├── dashboard.lua     -- Main entity dashboard with tabs, filters, state display
│   ├── dashboard_editor.lua  -- Lovelace dashboard editor (write access to HA)
│   ├── picker.lua        -- Telescope-based entity picker
│   ├── state_viewer.lua  -- Floating window entity state viewer
│   └── floating.lua      -- Shared floating window utilities
└── utils/
    └── logger.lua        -- Logging utility (respects config.logging.level)
```

### LSP Client Architecture

**Plugin uses modern Neovim LSP API (0.11+):**

1. **`lsp_client.lua:setup()`**:
   - Calls `vim.lsp.config('homeassistant', {...})` to register server config
   - Calls `vim.lsp.enable('homeassistant')` to enable for configured filetypes
   - Creates hidden keepalive buffer to ensure LSP stays running
   - Uses `vim.lsp.start()` to start server immediately

2. **LSP Communication:**
   - All entity/service data comes from LSP server via requests/notifications
   - Plugin sends `workspace/executeCommand` for cache reload
   - Completion, hover, diagnostics are handled by LSP server
   - No direct WebSocket communication in plugin code

3. **Hidden Keepalive Buffer:**
   - Created with `vim.api.nvim_create_buf(false, true)`
   - Named `homeassistant-keepalive.yaml`
   - Keeps LSP server alive even when no HA files are open
   - Essential for dashboard and UI features

### UI Components

**Dashboard (`ui/dashboard.lua`):**
- Multi-tab interface (entities, services)
- View modes: domains (grouped by entity type), areas (grouped by location)
- Collapsible sections with `<Tab>` key
- Filter input with `<C-f>` (uses `M.filter_text`)
- Interactive entity control (lights, switches, climate)
- Real-time state updates via LSP notifications

**Dashboard Editor (`ui/dashboard_editor.lua`):**
- Edits Lovelace dashboards (storage-mode only, not YAML-mode)
- Uses LSP commands: `homeassistant.listDashboards`, `homeassistant.getDashboard`, `homeassistant.updateDashboard`
- JSON format for editing (not YAML)
- Auto-save on `:w` sends updates to Home Assistant

**State Viewer (`ui/state_viewer.lua`):**
- Floating window showing entity state + attributes
- Uses LSP request for entity data
- Bound to `:HAEntityState <entity_id>` command

**Picker (`ui/picker.lua`):**
- Optional Telescope integration
- Entity selection and control
- Fallback to `vim.ui.select` if Telescope unavailable

### Configuration System

**Default config structure** (`config.lua`):
```lua
{
  lsp = {
    enabled = true,
    cmd = { "homeassistant-lsp", "--stdio" },
    filetypes = { "yaml", "yaml.homeassistant", "python", "json" },
    settings = {
      homeassistant = {
        host = "ws://localhost:8123/api/websocket",
        token = nil,  -- REQUIRED
        timeout = 5000,
      },
      cache = { enabled = true, ttl = 300 },
      diagnostics = { enabled = true, debounce = 500 },
      completion = { minChars = 3 },
    },
  },
  ui = { dashboard = {...}, state_viewer = {...} },
  logging = { level = "info" },
  keymaps = { enabled = true, dashboard = "<leader>hd", ... },
}
```

**Config is merged using `vim.tbl_deep_extend("force", defaults, user_config)`**

### User Commands

All commands registered in `init.lua:_register_commands()`:

| Command | Function | Description |
|---------|----------|-------------|
| `:HADashboard` | `ui.dashboard.toggle()` | Toggle entity dashboard |
| `:HAEntityState <id>` | `ui.state_viewer.show()` | Show entity state in floating window |
| `:HAReloadCache` | LSP `workspace/executeCommand` | Send cache reload command to LSP |
| `:HAPicker` | `ui.picker.entities()` | Open Telescope entity picker |
| `:HAEditDashboard` | `ui.dashboard_editor.pick_dashboard()` | Edit Lovelace dashboards |
| `:HAComplete` | `vim.lsp.buf.completion()` | Manual completion trigger (Insert mode) |
| `:HADebug` | Show debug info | Plugin state, LSP status, filetype |

### Keymap System

**Keymaps are conditionally set based on config:**
- `config.keymaps.enabled = false` disables all keymaps
- Individual keymaps can be set to `nil` to disable
- Picker keymap only registered if Telescope is available
- All keymaps bound in normal mode with `silent = true`

**Implementation in `init.lua:_setup_keymaps()`:**
```lua
-- Only sets keymap if maps.dashboard is not nil
if maps.dashboard then
  vim.keymap.set("n", maps.dashboard, "<cmd>HADashboard<cr>", {...})
end
```

## Important Implementation Details

### LSP Server Dependency

**The plugin REQUIRES homeassistant-lsp to be installed globally:**
```bash
npm install -g homeassistant-lsp
```

**Why:**
- Plugin doesn't bundle the LSP server
- Users must install separately via npm
- Default command: `{ "homeassistant-lsp", "--stdio" }`
- Can be overridden in config if installed elsewhere

### File Type Handling

**Default filetypes:** `yaml`, `yaml.homeassistant`, `python`, `json`

**Special considerations:**
- `yaml.homeassistant` is a custom filetype for HA config files
- `json` added for dashboard editing (Lovelace dashboards use JSON)
- LSP attaches to these filetypes automatically
- Completion works in ALL YAML/Python files (not just HA configs)

### Completion Behavior

**Two-stage completion system (implemented in LSP server, not plugin):**
1. **Domain completion:** Type 3+ chars → see matching domains (e.g., `inp` → `input_number`)
2. **Entity completion:** Type `domain.` → see all entities in domain

**Plugin's role:**
- Provides `:HAComplete` command to manually trigger
- LSP server handles all completion logic
- Works with any LSP-compatible completion plugin (blink.cmp, nvim-cmp, etc.)

### Dashboard Write Access

**Dashboard editor has write permissions to Home Assistant:**
- Can modify/delete dashboard configurations
- Only works with storage-mode dashboards (created via UI)
- YAML-mode dashboards are read-only (must edit in config files)
- Uses LSP command `homeassistant.updateDashboard` to save changes

**Security consideration:** Users must trust the plugin with their HA access token.

### Logger Usage

**Centralized logging in `utils/logger.lua`:**
```lua
local logger = require("homeassistant.utils.logger")
logger.debug("message")  -- Only shown if config.logging.level = "debug"
logger.info("message")
logger.warn("message")
logger.error("message")
```

**Log output:**
- Uses `vim.notify()` for user-facing messages
- Debug logs only visible with `:messages`
- Respects `config.logging.level` setting

## Common Development Patterns

### Adding a New UI Component

1. Create module in `lua/homeassistant/ui/`
2. Use `require("homeassistant.ui.floating")` for window creation
3. Get LSP client: `require("homeassistant").get_lsp_client()`
4. Check connection: `lsp_client.is_connected()`
5. Make LSP request: `client.request('custom/method', params, callback)`

### Adding a New Command

1. Add command in `init.lua:_register_commands()`
2. Use `vim.api.nvim_create_user_command()`
3. Add corresponding keymap in `_setup_keymaps()` if needed
4. Update default config in `config.lua` if adding new keymap

### Working with LSP Client

```lua
-- Get LSP client
local lsp_client = require("homeassistant").get_lsp_client()

-- Check if connected
if not lsp_client or not lsp_client.is_connected() then
  vim.notify("LSP not connected", vim.log.levels.ERROR)
  return
end

-- Get vim LSP client instance
local client = lsp_client.get_client()

-- Make custom request
client.request('workspace/executeCommand', {
  command = "homeassistant.someCommand",
  arguments = {},
}, function(err, result)
  if err then
    logger.error("Request failed: " .. err.message)
  else
    -- Process result
  end
end)
```

### Error Handling Pattern

```lua
-- Always wrap in pcall for robustness
local ok, err = pcall(function()
  -- Your code here
end)

if not ok then
  logger.error("Operation failed: " .. tostring(err))
  vim.notify("Error: " .. tostring(err), vim.log.levels.ERROR)
end
```

## Testing Strategy

**Primary testing method is manual testing + health check:**

1. **Install plugin locally:**
   ```lua
   -- In Neovim config
   {
     dir = "~/git/homeassistant-nvim",  -- Local path
     dependencies = {...},
     config = function() ... end,
   }
   ```

2. **Run health check:**
   ```vim
   :checkhealth homeassistant
   ```

3. **Test features manually:**
   - Try each command (`:HADashboard`, `:HAPicker`, etc.)
   - Test completion in YAML/Python files
   - Test dashboard editor
   - Check LSP hover on entity IDs
   - Verify diagnostics for invalid entities

**No automated test suite currently exists.**

## Code Style

**Enforced by StyLua (`.stylua.toml`):**
- 100 character line width
- 2-space indentation
- Unix line endings
- Double quotes preferred
- Always use call parentheses
- Never collapse simple statements

**Enforced by Luacheck (`.luacheckrc`):**
- Max line length: 100
- Ignore unused arguments (common in callbacks)
- Global `vim` object allowed
- No warnings for test files

## Dependencies

**Required:**
- Neovim >= 0.9.0 (uses modern LSP API)
- homeassistant-lsp (npm package, installed globally)
- nvim-lspconfig (Neovim plugin)

**Optional:**
- telescope.nvim (for `:HAPicker` command)

**Runtime dependencies:**
- Home Assistant instance with WebSocket API
- Long-lived access token from HA

## Common Pitfalls

1. **LSP not starting:** Check that `homeassistant-lsp` is in PATH
2. **No completion:** Verify LSP is connected with `:LspInfo`
3. **Invalid token:** Check `:messages` for auth errors
4. **Dashboard editor fails:** Only works with storage-mode dashboards
5. **Keymaps not working:** Check `config.keymaps.enabled` and individual keymap config
6. **Telescope picker unavailable:** Falls back to `vim.ui.select` automatically

## External Documentation

- [Home Assistant WebSocket API](https://developers.home-assistant.io/docs/api/websocket)
- [Neovim LSP docs](https://neovim.io/doc/user/lsp.html)
- [homeassistant-lsp repository](https://github.com/myakove/homeassistant-lsp)
