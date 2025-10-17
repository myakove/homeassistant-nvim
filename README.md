# homeassistant.nvim

A Neovim plugin for seamless Home Assistant integration using WebSocket API, providing intelligent auto-completion, entity management, and configuration assistance.

## Features

- 🔌 **WebSocket Connection**: Real-time connection to Home Assistant via official WebSocket API
- 🎯 **Smart Auto-completion**: Real-time entity and service completion from your Home Assistant instance
- 📊 **Live State Viewing**: View and monitor entity states directly in Neovim
- 📝 **Dashboard Editor**: Edit Home Assistant Lovelace dashboards directly from Neovim
- 🎨 **Dashboard**: Quick access to entities in a floating window
- 🔄 **Real-time Updates**: Auto-updating entity states via WebSocket events

## Requirements

- Neovim >= 0.8.0
- **`uv` (REQUIRED)** - Handles Python and dependencies automatically
- **Completion engine (pick one):**
  - [blink.cmp](https://github.com/saghen/blink.cmp) - Modern, fast completion (recommended)
  - [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) - Popular completion framework
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional) - For entity picker
- Home Assistant instance with API access

## Installation

### 1. Install uv (Required)

The plugin uses `uv run --with websockets` to automatically manage Python dependencies on-the-fly. **No manual installation of Python packages needed!**

Install uv:
```bash
# Linux/macOS
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or via package manager
sudo dnf install uv      # Fedora
yay -S uv                # Arch
brew install uv          # macOS
```

**Why uv?**
- ✅ Automatically manages Python and dependencies
- ✅ Zero installation - downloads everything on-demand
- ✅ No `pip install` needed
- ✅ No conflicts with system Python
- ✅ Fast and reliable
- ✅ Works everywhere

### 2. Install Plugin with lazy.nvim

**With blink.cmp (recommended):**

```lua
{
  "myakove/homeassistant-nvim",
  dependencies = {
    "saghen/blink.cmp", -- optional but recommended
    "nvim-telescope/telescope.nvim", -- optional
  },
  config = function()
    require("homeassistant").setup({
      homeassistant = {
        host = "http://homeassistant.local:8123",
        token = "your_long_lived_access_token_here",
      },
    })
  end,
}

-- Configure blink.cmp sources
{
  "saghen/blink.cmp",
  opts = {
    sources = {
      default = { "lsp", "path", "snippets", "buffer", "homeassistant_entities", "homeassistant_services" },
      providers = {
        homeassistant_entities = {
          name = "HomeAssistant",
          module = "homeassistant.completion.blink_entities",
          score_offset = 100, -- Higher priority in YAML/Python files
        },
        homeassistant_services = {
          name = "HomeAssistant",
          module = "homeassistant.completion.blink_services",
          score_offset = 100, -- Higher priority in YAML/Python files
        },
      },
    },
  },
}
```

**With nvim-cmp:**

```lua
{
  "myakove/homeassistant-nvim",
  dependencies = {
    "hrsh7th/nvim-cmp",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("homeassistant").setup({
      homeassistant = {
        host = "http://homeassistant.local:8123",
        token = "your_long_lived_access_token_here",
      },
    })
  end,
}

-- Configure nvim-cmp sources
require("cmp").setup({
  sources = {
    { name = "homeassistant_entities" },
    { name = "homeassistant_services" },
    -- ... other sources
  },
})
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "myakove/homeassistant-nvim",
  requires = {
    "hrsh7th/nvim-cmp",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("homeassistant").setup({
      homeassistant = {
        host = "http://homeassistant.local:8123",
        token = "your_long_lived_access_token_here",
      },
    })
  end,
}
```

## Configuration

All configuration options with their **default values**:

<details>
<summary>Full Configuration Example</summary>

```lua
require("homeassistant").setup({
  homeassistant = {
    host = "http://localhost:8123",  -- Default: localhost
    token = nil,                     -- REQUIRED: Your long-lived access token
    timeout = 5000,                  -- Default: 5000ms
    verify_ssl = true,               -- Default: true
  },
  
  completion = {
    enabled = true,                  -- Default: true
    entity_prefix = "entity:",       -- Default: "entity:"
    service_prefix = "service:",     -- Default: "service:"
    auto_trigger = true,             -- Default: true
  },
  
  lsp = {
    enabled = true,                  -- Default: true - Enable LSP features
    hover = true,                    -- Default: true - Smart K keymap (HA entity or LSP hover)
    diagnostics = true,              -- Default: true - Validate entity references
    go_to_definition = true,         -- Default: true - gd keymap for entities
  },
  
  ui = {
    dashboard = {
      width = 0.8,                   -- Default: 0.8 (80% of screen)
      height = 0.8,                  -- Default: 0.8
      border = "rounded",            -- Default: "rounded"
      favorites = {},                -- Default: empty list
    },
    state_viewer = {
      border = "rounded",            -- Default: "rounded"
      show_attributes = true,        -- Default: true
    },
  },
  
  cache = {
    enabled = true,                  -- Default: true
    ttl = 300,                       -- Default: 300 seconds (5 minutes)
    auto_refresh = true,             -- Default: true
  },
  
  logging = {
    level = "info",                  -- Default: "info" (debug, info, warn, error)
  },
  
  keymaps = {
    enabled = true,                  -- Default: true - Set to false to disable all keymaps
    dashboard = "<leader>hd",        -- Default: <leader>hd - Toggle dashboard
    picker = "<leader>hp",           -- Default: <leader>hp - Entity picker (requires telescope)
    edit_dashboard = "<leader>he",   -- Default: <leader>he - Edit HA dashboards
    reload_cache = "<leader>hr",     -- Default: <leader>hr - Reload cache
    debug = "<leader>hD",            -- Default: <leader>hD - Show debug info
  },
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
  homeassistant = {
    host = os.getenv("HOMEASSISTANT_HOST") or "http://localhost:8123",
    token = os.getenv("HOMEASSISTANT_TOKEN"),  -- Read from environment
  },
})
```

Then set in your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
export HOMEASSISTANT_HOST="http://homeassistant.local:8123"
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
- `:HAReloadCache` - Manually reload entity cache
- `:HAHover` - Show entity info for entity under cursor
- `:HADebug` - Show plugin debug information (includes HA version when connected)
- `:checkhealth homeassistant` - Run health check (verify installation and connection)

### LSP Features

The plugin provides LSP-like features for Home Assistant YAML and Python files:

**Smart Hover (`K` key):**
- Press `K` on any entity ID → Shows Home Assistant entity info
- Press `K` on code → Shows normal LSP hover
- **Performance:** <1ms when HA disconnected, ~10-50ms when connected (cached)
- Shows:
  - Entity name and domain
  - Current state
  - All attributes

**Diagnostics:**
- Automatically validates entity references
- Shows warnings for unknown/invalid entities
- Updates on file save
- **Performance:** Only runs on save, uses cached entities

**Go-to-Definition (`gd` key):**
- Place cursor on entity ID
- Press `gd` to open detailed entity view
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
│   ├── api/                    # Home Assistant API client
│   ├── completion/             # Completion sources (blink.cmp & nvim-cmp)
│   ├── lsp/                    # LSP features (hover, diagnostics)
│   ├── ui/                     # UI components (dashboard, picker, editor)
│   └── utils/                  # Utilities (logger, cache)
├── scripts/                    # Python helper scripts
│   └── websocket_client.py     # WebSocket client
├── plugin/                     # Vim plugin loader
├── doc/                        # Vim help documentation
└── README.md
```

## Acknowledgments

- Home Assistant team for the excellent WebSocket API
- Neovim community for the powerful plugin ecosystem
