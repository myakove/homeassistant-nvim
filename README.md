# homeassistant.nvim

A Neovim plugin for seamless Home Assistant integration using WebSocket API, providing intelligent auto-completion, entity management, and configuration assistance.

## Features

- 🔌 **WebSocket Connection**: Real-time connection to Home Assistant via official WebSocket API
- 🎯 **Smart Auto-completion**: Real-time entity and service completion from your Home Assistant instance
- 📊 **Live State Viewing**: View and monitor entity states directly in Neovim
- ⚡ **Quick Actions**: Control entities and call services without leaving your editor
- 🎨 **Dashboard**: Quick access to entities in a floating window
- 🔄 **Real-time Updates**: Auto-updating entity states via WebSocket events

## Requirements

- Neovim >= 0.8.0
- **`uv` (REQUIRED)** - Handles Python and dependencies automatically
- **Completion engine (pick one):**
  - [blink.cmp](https://github.com/saghen/blink.cmp) - Modern, fast completion (recommended)
  - [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) - Popular completion framework
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) - For entity picker (optional)
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
  "myakove/homeassistant.nvim",
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
  "myakove/homeassistant.nvim",
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
  "myakove/homeassistant.nvim",
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

<details>
<summary>Full Configuration Example</summary>

```lua
require("homeassistant").setup({
  homeassistant = {
    host = "http://localhost:8123",
    token = nil, -- REQUIRED: Your long-lived access token
    timeout = 5000,
    verify_ssl = true,
  },
  
  completion = {
    enabled = true,
    entity_prefix = "entity:",
    service_prefix = "service:",
    auto_trigger = true,
  },
  
  lsp = {
    enabled = true, -- Enable LSP features
    hover = true, -- Press K to show entity info
    diagnostics = true, -- Show warnings for unknown entities
    go_to_definition = true, -- Press gd to view entity details
  },
  
  ui = {
    dashboard = {
      width = 0.8,
      height = 0.8,
      border = "rounded",
      favorites = {
        "light.living_room",
        "climate.thermostat",
        "sensor.temperature",
      },
    },
    state_viewer = {
      border = "rounded",
      show_attributes = true,
    },
  },
  
  cache = {
    enabled = true,
    ttl = 300, -- 5 minutes
    auto_refresh = true,
  },
  
  logging = {
    level = "info", -- debug, info, warn, error
  },
})
```
</details>

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
- `:HAServiceCall` - Interactive service call prompt
- `:HAPicker` - Open Telescope picker for entity selection
- `:HAReloadCache` - Manually reload entity cache

### LSP Features

The plugin provides LSP-like features for Home Assistant YAML and Python files:

**Hover Documentation (K):**
- Place cursor on any entity ID (e.g., `sensor.temperature`)
- Press `K` to see:
  - Entity name and domain
  - Current state
  - All attributes

**Diagnostics:**
- Automatically validates entity references
- Shows warnings for unknown/invalid entities
- Updates on file save

**Go-to-Definition (gd):**
- Place cursor on entity ID
- Press `gd` to open detailed entity view

**Example:**
```yaml
automation:
  - alias: "Turn on lights"
    trigger:
      - platform: state
        entity_id: sensor.motion  # Press K here for info
    action:
      - service: light.turn_on
        target:
          entity_id: light.unknown  # Warning: Unknown entity
```

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

### Keybindings Example

```lua
vim.keymap.set("n", "<leader>hd", "<cmd>HADashboard<cr>", { desc = "HA Dashboard" })
vim.keymap.set("n", "<leader>hp", "<cmd>HAPicker<cr>", { desc = "HA Entity Picker" })
vim.keymap.set("n", "<leader>hc", "<cmd>HAServiceCall<cr>", { desc = "HA Service Call" })
vim.keymap.set("n", "<leader>hr", "<cmd>HAReloadCache<cr>", { desc = "HA Reload Cache" })
```

## Architecture

This plugin uses the official Home Assistant WebSocket API for all communications:

- **Real-time connection**: Persistent WebSocket connection for low latency
- **Event-driven**: Subscribe to state changes and events
- **Efficient**: No polling required, updates pushed from Home Assistant
- **Official protocol**: Uses the same API as Home Assistant's frontend

## Troubleshooting

### Connection Issues

If you're having trouble connecting:

1. **Verify `uv` is installed:** `uv --version`
2. **Verify Home Assistant URL** is correct (including `http://` or `https://`)
3. **Check your access token** is valid (from HA profile page)
4. **Enable debug logging:** Set `logging.level = "debug"` in config and check `:messages`

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
│   ├── api/                    # Home Assistant API client
│   ├── completion/             # nvim-cmp sources
│   ├── ui/                     # UI components
│   ├── actions/                # Service calls and actions
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
