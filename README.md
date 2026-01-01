# k8s.nvim

A Neovim plugin for managing Kubernetes resources.

## Features

- Browse and manage Kubernetes resources (Pod, Deployment, Service, ConfigMap, Secret, Node, Namespace)
- View resource details with `kubectl describe`
- Execute commands in pods (`kubectl exec`)
- View pod logs (`kubectl logs`)
- Port forwarding with connection management
- Scale deployments
- Restart deployments
- Delete resources
- Filter resources by name/namespace
- Switch between contexts and namespaces
- Auto-refresh resource list
- Secret value masking

## Requirements

- Neovim >= 0.10.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured with cluster access
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## Installation

### lazy.nvim

```lua
{
  "skanehira/k8s.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("k8s").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "skanehira/k8s.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("k8s").setup()
  end,
}
```

## Configuration

```lua
require("k8s").setup({
  -- Auto-refresh interval in milliseconds (default: 5000)
  refresh_interval = 5000,

  -- kubectl command timeout in milliseconds (default: 30000)
  timeout = 30000,

  -- Default namespace (default: "default")
  default_namespace = "default",

  -- Default resource kind (default: "Pod")
  default_kind = "Pod",

  -- Transparent window background (default: false)
  transparent = false,

  -- Custom keymaps (optional)
  keymaps = {
    describe = { key = "d", desc = "Describe resource" },
    delete = { key = "D", desc = "Delete resource" },
    logs = { key = "l", desc = "View logs" },
    logs_previous = { key = "P", desc = "Previous logs" },
    exec = { key = "e", desc = "Execute shell" },
    scale = { key = "s", desc = "Scale resource" },
    restart = { key = "X", desc = "Restart resource" },
    port_forward = { key = "p", desc = "Port forward" },
    port_forward_list = { key = "F", desc = "Port forwards list" },
    filter = { key = "/", desc = "Filter" },
    refresh = { key = "r", desc = "Refresh" },
    resource_menu = { key = "R", desc = "Resources" },
    context_menu = { key = "C", desc = "Context" },
    namespace_menu = { key = "N", desc = "Namespace" },
    toggle_secret = { key = "S", desc = "Toggle secret" },
    help = { key = "?", desc = "Help" },
    quit = { key = "q", desc = "Hide" },
    close = { key = "<C-c>", desc = "Close" },
    back = { key = "<C-h>", desc = "Back" },
    select = { key = "<CR>", desc = "Select" },
  },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:K8s` | Toggle k8s.nvim window |
| `:K8s open` | Open k8s.nvim with default resource kind |
| `:K8s <kind>` | Open with specific resource kind (e.g., `:K8s pods`) |
| `:K8s close` | Close k8s.nvim window |
| `:K8s context <name>` | Switch to specified context |
| `:K8s namespace <name>` | Switch to specified namespace |
| `:K8s portforwards` | Show port forwards list |

### Keymaps

#### Resource List View

| Key | Action | Description |
|-----|--------|-------------|
| `<CR>` | select | Select resource (same as describe) |
| `d` | describe | Show resource details |
| `l` | logs | View pod logs |
| `P` | logs_previous | View previous pod logs |
| `e` | exec | Execute shell in pod |
| `p` | port_forward | Start port forwarding |
| `F` | port_forward_list | Show active port forwards |
| `D` | delete | Delete resource |
| `s` | scale | Scale deployment |
| `X` | restart | Restart deployment |
| `r` | refresh | Refresh resource list |
| `/` | filter | Filter resources |
| `R` | resource_menu | Switch resource kind |
| `S` | toggle_secret | Toggle secret value visibility |
| `C` | context_menu | Switch context |
| `N` | namespace_menu | Switch namespace |
| `?` | help | Show help |
| `q` | quit | Hide window |
| `<C-c>` | close | Close window |
| `<C-h>` | back | Go back to previous view |

#### Describe View

| Key | Action | Description |
|-----|--------|-------------|
| `l` | logs | View pod logs (Pod only) |
| `e` | exec | Execute shell in pod (Pod only) |
| `D` | delete | Delete resource |
| `S` | toggle_secret | Toggle secret value visibility |
| `?` | help | Show help |
| `q` | quit | Hide window |
| `<C-c>` | close | Close window |
| `<C-h>` | back | Go back to list view |

#### Port Forward List View

| Key | Action | Description |
|-----|--------|-------------|
| `D` | stop | Stop selected port forward |
| `?` | help | Show help |
| `q` | quit | Hide window |
| `<C-c>` | close | Close window |
| `<C-h>` | back | Go back to previous view |

## Supported Resources

| Resource | exec | logs | scale | restart | port_forward |
|----------|:----:|:----:|:-----:|:-------:|:------------:|
| Pod | ✓ | ✓ | - | - | ✓ |
| Deployment | - | - | ✓ | ✓ | ✓ |
| Service | - | - | - | - | ✓ |
| ConfigMap | - | - | - | - | - |
| Secret | - | - | - | - | - |
| Node | - | - | - | - | - |
| Namespace | - | - | - | - | - |

## License

MIT
