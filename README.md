# homeassistant.nvim

A Neovim plugin for seamless Home Assistant integration via LSP, providing intelligent auto-completion, entity management, and configuration assistance.

## Features

- 🚀 **LSP-Based Architecture**: Built on [homeassistant-lsp](https://github.com/myakove/homeassistant-lsp) for robust language server features
- 🎯 **Smart Auto-completion**: Real-time entity and service completion from your Home Assistant instance
- 💡 **Hover Documentation**: View entity states and details on hover
- 🔍 **Diagnostics**: Real-time validation of entity IDs and service calls
- 📝 **Dashboard Editor**: Edit Home Assistant Lovelace dashboards directly from Neovim
- 📊 **Live State Viewing**: View and monitor entity states directly in Neovim
- 🎨 **Dashboard**: Quick access to entities in a floating window

## Requirements

- Neovim >= 0.9.0
- **[homeassistant-lsp](https://github.com/myakove/homeassistant-lsp)** - The LSP server (install globally with npm)
- **[nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)** - LSP configuration
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional) - For entity picker
- Home Assistant instance with API access

## Development

### Pre-commit Hooks

This project uses pre-commit hooks to ensure code quality. To set up:

```bash
# Install the hooks
prek install

# Run on all files
prek run
```

The hooks include:
- **StyLua** - Lua code formatter
- **Luacheck** - Lua linter and static analyzer
- Standard checks (trailing whitespace, end-of-file, etc.)

## Installation

### 1. Install homeassistant-lsp (Required)

The plugin requires the Home Assistant LSP server to be installed globally:

```bash
npm install -g homeassistant-lsp
```

Or see the [homeassistant-lsp installation guide](https://github.com/myakove/homeassistant-lsp#installation) for more options.

### 2. Install Plugin with lazy.nvim

**Basic setup (loads on all files):**

```lua
{
  "myakove/homeassistant-nvim",
  dependencies = {
    "neovim/nvim-lspconfig",          -- Required for LSP
    "nvim-telescope/telescope.nvim",  -- Optional, for entity picker
  },
  event = { "BufRead", "BufNewFile" }, -- Load on file open
  config = function()
    require("homeassistant").setup({
      lsp = {
        enabled = true,
        -- LSP server command (default: homeassistant-lsp --stdio)
        cmd = { "homeassistant-lsp", "--stdio" },
        -- File types to attach LSP to
        filetypes = { "yaml", "yaml.homeassistant", "python", "json" },
        -- LSP server settings
        settings = {
          homeassistant = {
            host = "ws://homeassistant.local:8123/api/websocket",
            token = "your_long_lived_access_token_here",
            timeout = 5000,
          },
          cache = {
            enabled = true,
            ttl = 300, -- 5 minutes
          },
          diagnostics = {
            enabled = true,
            debounce = 500,
          },
        },
      },
      -- Optional: UI settings
      ui = {
        dashboard = {
          width = 0.8,
          height = 0.8,
          border = "rounded",
        },
      },
      -- Optional: Custom keymaps (set to false to disable defaults)
      keymaps = {
        dashboard = "<leader>hd",
        picker = "<leader>hp",
        reload_cache = "<leader>hr",
        debug = "<leader>hD",
        edit_dashboard = "<leader>he",
      },
    })
  end,
}
```

**Path-based loading (recommended if you only work with HA files in specific directories):**

```lua
{
  "myakove/homeassistant-nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    "nvim-telescope/telescope.nvim",
  },
  event = { "BufRead", "BufNewFile" }, -- Plugin file loads on file open
  config = function()
    require("homeassistant").setup({
      -- Only initialize when files match these paths
      paths = { "config/homeassistant/", "~/dotfiles/" },
      lsp = {
        enabled = true,
        cmd = { "homeassistant-lsp", "--stdio" },
        filetypes = { "yaml", "yaml.homeassistant", "python", "json" },
        settings = {
          homeassistant = {
            host = "ws://homeassistant.local:8123/api/websocket",
            token = "your_long_lived_access_token_here",
            timeout = 5000,
          },
          cache = { enabled = true, ttl = 300 },
          diagnostics = { enabled = true, debounce = 500 },
        },
      },
    })
  end,
}
```

**Note:** Completion is provided by the LSP server and works automatically with any LSP-compatible completion plugin (blink.cmp, nvim-cmp, coq_nvim, etc.). No additional configuration needed!

## Configuration

All configuration options with their **default values**:

### Path-Based Conditional Loading

By default, the plugin loads automatically on all files. You can configure it to only load when files match specific path patterns:

```lua
require("homeassistant").setup({
  -- Only load plugin when editing files in Home Assistant config directory
  paths = { "config/homeassistant/", "/homeassistant/" },

  -- Or match by file extension
  paths = { "%.yaml$", "%.yml$" },

  -- Or combine both
  paths = { "config/homeassistant/", "%.yaml$" },

  -- Patterns are Lua patterns (see :help pattern)
  -- Use %- to match literal - (hyphen)
  paths = { "home%-assistant%-config/" },

  -- If paths is nil or empty, plugin loads everywhere (default)
  paths = nil,  -- or paths = {}
})
```

**When to use path-based loading:**
- ✅ You only work with Home Assistant files in specific directories
- ✅ You want to reduce plugin overhead when editing other files
- ✅ You have multiple Home Assistant instances and want to load selectively

**Note:** If `paths` is not configured (or is `nil`/empty), the plugin loads on all files for backward compatibility.

**Important distinction:**
- `paths` controls **when the plugin initializes** (loads only for matching file paths)
- `lsp.filetypes` controls **which file types get LSP features** (completion, hover, diagnostics)
- **When `paths` is configured**: LSP only attaches to buffers that match **BOTH** the configured paths **AND** the configured filetypes
- **When `paths` is NOT configured**: LSP attaches to all buffers matching the configured filetypes (default behavior)

**Benefits of path-based LSP attachment:**
- ✅ Prevents interference with other LSPs (e.g., Lua LSP won't conflict on Lua files in matching paths)
- ✅ More efficient: LSP only runs where needed
- ✅ Better isolation: Each file type gets its appropriate LSP

**Example:**
```lua
require("homeassistant").setup({
  -- Plugin only loads when editing files in Home Assistant config directory
  paths = { "config/homeassistant/" },

  -- LSP attaches only to YAML/Python/JSON files in matching paths
  -- Other file types (like Lua) in matching paths won't get HA LSP attached
  lsp = {
    filetypes = { "yaml", "yaml.homeassistant", "python", "json" },
  },
})
```

**Real-world scenario:**
If you have `paths = { "~/dotfiles/" }` and open a Lua file in `~/dotfiles/config.lua`:
- ✅ Plugin file loads (because path matches)
- ✅ Plugin initializes (because path matches)
- ❌ HA LSP does NOT attach (because Lua is not in `filetypes`)
- ✅ Your Lua LSP works normally (no interference)

<details>
<summary>Full Configuration Example</summary>

```lua
require("homeassistant").setup({
  -- LSP Server configuration
  lsp = {
    enabled = true,                    -- Default: true - Enable LSP client
    cmd = { "homeassistant-lsp", "--stdio" }, -- Default: homeassistant-lsp --stdio
    filetypes = { "yaml", "yaml.homeassistant", "python", "json" }, -- Default file types
    root_dir = nil,                    -- Default: auto-detect via lspconfig

    settings = {
      homeassistant = {
        host = "ws://localhost:8123/api/websocket", -- WebSocket URL
        token = nil,                   -- REQUIRED: Your long-lived access token
        timeout = 5000,                -- Default: 5000ms
      },
      cache = {
        enabled = true,                -- Default: true
        ttl = 300,                     -- Default: 300 seconds (5 minutes)
      },
      diagnostics = {
        enabled = true,                -- Default: true
        debounce = 500,                -- Default: 500ms
      },
      completion = {
        minChars = 3,                  -- Default: 3 - Min characters for domain completion
      },
    },
  },

  -- UI settings (Neovim-specific)
  ui = {
    dashboard = {
      width = 0.8,                     -- Default: 0.8 (80% of screen)
      height = 0.8,                    -- Default: 0.8
      border = "rounded",              -- Default: "rounded"
      favorites = {},                  -- Default: empty list
    },
    state_viewer = {
      border = "rounded",              -- Default: "rounded"
      show_attributes = true,          -- Default: true
    },
  },

  -- Logging (plugin-level, not LSP)
  logging = {
    level = "info",                    -- Default: "info" (debug, info, warn, error)
  },

  -- Keymaps
  keymaps = {
    enabled = true,                    -- Default: true - Set to false to disable all keymaps
    dashboard = "<leader>hd",          -- Default: <leader>hd - Toggle dashboard
    picker = "<leader>hp",             -- Default: <leader>hp - Entity picker (requires telescope)
    edit_dashboard = "<leader>he",     -- Default: <leader>he - Edit HA dashboards
    reload_cache = "<leader>hr",       -- Default: <leader>hr - Reload LSP cache
    debug = "<leader>hD",              -- Default: <leader>hD - Show debug info
  },

  -- Path-based loading (optional)
  -- If nil or empty, plugin loads on all files (default behavior)
  -- If set to array of patterns, plugin only loads when file path matches any pattern
  -- Patterns are Lua patterns (see :help pattern)
  paths = nil,                         -- Default: nil - Load everywhere
  -- Example: paths = { "config/homeassistant/", "/homeassistant/", "%.yaml$" }
  -- Example: paths = { "home%-assistant%-config/" }  -- Use %- to match literal -
})
```
</details>

**Keymaps Configuration:**

The plugin sets up default keymaps automatically. You can:
- **Disable all keymaps:** Set `keymaps.enabled = false`
- **Customize individual keymaps:** Change the key in config
- **Set a keymap to `nil`:** Disable that specific keymap

```lua
require("homeassistant").setup({
  keymaps = {
    enabled = true,
    dashboard = "<leader>ha",      -- Custom keymap
    picker = nil,                  -- Disable picker keymap
    reload_cache = "<F5>",         -- Use F5 for reload
  },
})
```
</details>

### Using Environment Variables

For better security, you can use environment variables to avoid hardcoding sensitive tokens in your config:

```lua
require("homeassistant").setup({
  lsp = {
    settings = {
      homeassistant = {
        host = os.getenv("HOMEASSISTANT_HOST") or "ws://localhost:8123/api/websocket",
        token = os.getenv("HOMEASSISTANT_TOKEN"),  -- Read from environment
      },
    },
  },
})
```

Then set in your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export HOMEASSISTANT_HOST="ws://homeassistant.local:8123/api/websocket"
export HOMEASSISTANT_TOKEN="your-long-lived-access-token-here"
```

**Benefits:**
- ✅ Tokens not stored in config files or git repos
- ✅ Easy to switch between dev/prod environments

## Usage

### Getting a Long-Lived Access Token

1. Go to your Home Assistant profile: `http://your-ha-instance:8123/profile`
2. Scroll down to "Long-Lived Access Tokens"
3. Click "Create Token"
4. Give it a name (e.g., "Neovim Plugin")
5. Copy the token and add it to your configuration

### Commands

- `:HADashboard` - Toggle the entity dashboard
- `:HAEntityState <entity_id>` - View entity state in floating window
- `:HAPicker` - Open Telescope picker for entity selection
- `:HAEditDashboard` - Edit Home Assistant Lovelace dashboards
- `:HAReloadCache` - Manually reload LSP entity cache
- `:HAComplete` - Manually trigger LSP completion
- `:HADebug` - Show plugin debug information
- `:checkhealth homeassistant` - Run health check (verify installation and LSP connection)

### LSP Features

The plugin uses a dedicated LSP server ([homeassistant-lsp](https://github.com/myakove/homeassistant-lsp)) that provides full language server features:

**Hover (`K` key):**
- Press `K` on any entity ID to see entity state and attributes
- Works in YAML and Python files
- Shows:
  - Entity name and current state
  - All attributes
  - Last changed/updated times

**Completion:**
- Automatic entity ID completion while typing
- Service name completion
- Domain completion
- Works with any LSP-compatible completion plugin

**Diagnostics:**
- Real-time validation of entity references
- Warns about unknown/invalid entities
- Validates service calls
- Debounced for performance (500ms by default)
- Falls back to LSP definition for code

**Example:**
```yaml
automation:
  - alias: "Turn on lights"
    trigger:
      - platform: state
        entity_id: sensor.motion  # Press K here for HA info
    action:
      - service: light.turn_on
        target:
          entity_id: light.unknown  # Warning: Unknown entity
```

**Manual Command:**
- `:HAHover` - Force show HA entity info (bypasses LSP fallback)

### Auto-completion

The plugin provides intelligent, context-aware completion in both **YAML** (`.yaml` and `.yml`) and **Python** (`.py`) files.

> **Note:** Completion is available in **all** YAML and Python files, not just Home Assistant configs. The triggers are specific enough that they won't interfere with regular YAML/Python work.

#### Two-Stage Completion System

**Stage 1: Domain Completion** (3+ characters)

Type any 3+ character word to see matching Home Assistant domains:

```yaml
# YAML example
inp         # Shows: input_number, input_text, input_boolean, input_select, input_datetime
sen         # Shows: sensor
lig         # Shows: light
dev         # Shows: device_tracker
```

```python
# Python/AppDaemon example
self.get_state("inp    # Shows domain suggestions
self.turn_on("cov      # Shows: cover
```

**Stage 2: Entity Completion** (domain + dot)

After selecting a domain, type `.` to see all entities in that domain:

```yaml
# YAML example
sensor.              # Shows all sensors
sensor.temp          # Filters to sensors containing "temp"
input_boolean.       # Shows all input_boolean entities
light.kitchen        # Filters to lights containing "kitchen"
```

```python
# Python/AppDaemon example
self.get_state("sensor.")         # All sensors
self.turn_on("light.living")      # Lights with "living"
self.call_service("climate.")     # All climate entities
```

#### Features

- **Domain completion**: Type 3+ characters (e.g., `inp`, `sen`) to see matching domains
- **Entity filtering**: Type after the dot to filter entities (e.g., `sensor.temp`)
- **Works with underscores**: `input_boolean.`, `device_tracker.`, etc.
- **Case-insensitive**: `sensor`, `Sensor`, `SENSOR` all work
- **Real-time data**: Entities and states are fetched directly from your Home Assistant instance

### Default Keymaps

The plugin automatically sets up these keymaps:

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>hd` | `:HADashboard` | Toggle entity dashboard |
| `<leader>hp` | `:HAPicker` | Open entity picker (requires telescope) |
| `<leader>he` | `:HAEditDashboard` | Edit HA Lovelace dashboards |
| `<leader>hr` | `:HAReloadCache` | Reload entity cache |
| `<leader>hD` | `:HADebug` | Show debug information |

**Customize or disable keymaps in your config:**

```lua
require("homeassistant").setup({
  keymaps = {
    enabled = true,               -- Set to false to disable all keymaps
    dashboard = "<leader>ha",     -- Change to your preferred key
    picker = nil,                 -- Set to nil to disable this keymap
    edit_dashboard = "<leader>he", -- Keep default
    reload_cache = "<F5>",        -- Use F5 for reload
    debug = "<leader>hD",         -- Keep default
  },
})
```

### Dashboard Editing

Edit Home Assistant Lovelace dashboards directly from Neovim:

**How it works:**

1. Run `:HAEditDashboard` or press `<leader>he`
2. Select a dashboard from the picker (Telescope or vim.ui.select)
3. Edit the configuration in JSON format
4. Save with `:w` to update Home Assistant
5. Changes appear immediately in HA's UI

**Features:**

- ✅ **Storage-mode dashboards only** - YAML-mode dashboards should be edited in your config files
- ✅ **JSON format** - Easy to read and edit with syntax highlighting
- ✅ **Real-time sync** - Changes saved directly to Home Assistant
- ✅ **Telescope picker** - Quick dashboard selection (with fallback to vim.ui.select)

**Example workflow:**

```vim
:HAEditDashboard      " Opens picker with available dashboards
" Select 'Home' dashboard
" Edit the JSON configuration
:w                    " Save to Home Assistant
```

**Configuration:**

```lua
require("homeassistant").setup({
  keymaps = {
    edit_dashboard = "<leader>he",  -- Or set to nil to disable
  },
})
```

**Note:** This feature allows **write access** to your Home Assistant instance to update dashboard configurations. Only storage-mode dashboards (created/edited via UI) can be modified through the API.

## Architecture

This plugin uses the official Home Assistant WebSocket API for all communications:

- **Real-time connection**: Persistent WebSocket connection for low latency
- **Event-driven**: Subscribe to state changes and events
- **Efficient**: No polling required, updates pushed from Home Assistant
- **Official protocol**: Uses the same API as Home Assistant's frontend

## Troubleshooting

### Health Check (Recommended First Step)

Run the health check to verify your setup:
```vim
:checkhealth homeassistant
```

This will check:
- ✅ uv installation and version
- ✅ Python 3 availability
- ✅ Plugin initialization
- ✅ WebSocket connection status
- ✅ Home Assistant version, location, and state
- ✅ Total entities and services
- ✅ Completion engine detection
- ✅ Optional dependencies (telescope.nvim)

### Connection Issues

If you're having trouble connecting:

1. **Run health check:** `:checkhealth homeassistant`
2. **Verify `uv` is installed:** `uv --version`
3. **Verify Home Assistant URL** is correct (including `http://` or `https://`)
4. **Check your access token** is valid (from HA profile page)
5. **Check plugin debug info:** `:HADebug` (shows HA version when connected)
6. **Enable debug logging:** Set `logging.level = "debug"` in config and check `:messages`

### uv not found

Install uv:
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Make sure `~/.cargo/bin` is in your `$PATH` (or restart your terminal after installation).

## Roadmap

- [x] WebSocket API client
- [x] Entity auto-completion
- [x] Service auto-completion
- [x] Dashboard UI
- [x] Real-time state updates
- [x] LSP features (hover, diagnostics, go-to-definition)
- [ ] Snippet generation for automations
- [ ] Blueprint editor support
- [ ] State history visualization
- [ ] Advanced YAML validation

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Project Structure

```
homeassistant-nvim/
├── lua/homeassistant/          # Lua plugin code
│   ├── init.lua                # Main entry point
│   ├── config.lua              # Configuration management
│   ├── health.lua              # Health check integration
│   ├── lsp_client.lua          # LSP client setup
│   ├── ui/                     # UI components
│   │   ├── dashboard.lua       # Entity dashboard
│   │   ├── dashboard_editor.lua # Lovelace dashboard editor
│   │   ├── picker.lua          # Telescope entity picker
│   │   ├── state_viewer.lua    # Entity state viewer
│   │   └── floating.lua        # Floating window utilities
│   └── utils/                  # Utilities
│       └── logger.lua          # Logging utility
├── plugin/                     # Vim plugin loader
├── doc/                        # Vim help documentation
└── README.md
```

**Note:** The heavy lifting (WebSocket, caching, completion, diagnostics, hover) is done by the separate [homeassistant-lsp](https://github.com/myakove/homeassistant-lsp) server. This plugin focuses on Neovim-specific UI and LSP client integration.

## Related Projects

- [homeassistant-lsp](https://github.com/myakove/homeassistant-lsp) - The LSP server powering this plugin

## Acknowledgments

- Home Assistant team for the excellent WebSocket API
- LSP community for the Language Server Protocol specification
- Neovim community for the powerful plugin ecosystem
