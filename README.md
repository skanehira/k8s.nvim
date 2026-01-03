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
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## Installation

### lazy.nvim

```lua
{
  "skanehira/k8s.nvim",
  dependencies = {
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
  -- kubectl command timeout in milliseconds (default: 30000)
  timeout = 30000,

  -- Default namespace (default: "default")
  default_namespace = "default",

  -- Default resource kind (default: "Pod")
  default_kind = "Pod",

  -- Transparent window background (default: false)
  transparent = false,

  -- Custom keymaps (optional, organized by view)
  keymaps = {
    -- Global keymaps (shared across all views)
    global = {
      quit = { key = "q", desc = "Hide" },
      close = { key = "<C-c>", desc = "Close" },
      back = { key = "<C-h>", desc = "Back" },
      help = { key = "?", desc = "Help" },
    },
    -- List view keymaps
    list = {
      select = { key = "<CR>", desc = "Select" },
      describe = { key = "d", desc = "Describe" },
      delete = { key = "D", desc = "Delete" },
      logs = { key = "l", desc = "Logs" },
      logs_previous = { key = "P", desc = "PrevLogs" },
      exec = { key = "e", desc = "Exec" },
      scale = { key = "s", desc = "Scale" },
      restart = { key = "X", desc = "Restart" },
      port_forward = { key = "p", desc = "PortFwd" },
      port_forward_list = { key = "F", desc = "PortFwdList" },
      filter = { key = "/", desc = "Filter" },
      refresh = { key = "r", desc = "Refresh" },
      resource_menu = { key = "R", desc = "Resources" },
      context_menu = { key = "C", desc = "Context" },
      namespace_menu = { key = "N", desc = "Namespace" },
    },
    -- Describe view keymaps
    describe = {
      toggle_secret = { key = "S", desc = "ToggleSecret" },
    },
    -- Port forward list keymaps
    port_forward_list = {
      stop = { key = "D", desc = "Stop" },
    },
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

All keymaps below are available, but resource-specific actions (logs, exec, scale, restart, port_forward) are only shown for resource kinds that support them. See [Supported Resources](#supported-resources) for details.

| Key | Action | Description |
|-----|--------|-------------|
| `<CR>` | select | Select resource (same as describe) |
| `d` | describe | Show resource details |
| `l` | logs | View pod logs (Pod only) |
| `P` | logs_previous | View previous pod logs (Pod only) |
| `e` | exec | Execute shell in pod (Pod only) |
| `p` | port_forward | Start port forwarding |
| `F` | port_forward_list | Show active port forwards |
| `D` | delete | Delete resource |
| `s` | scale | Scale deployment (Deployment only) |
| `X` | restart | Restart deployment (Deployment only) |
| `r` | refresh | Refresh resource list |
| `/` | filter | Filter resources |
| `R` | resource_menu | Switch resource kind |
| `C` | context_menu | Switch context |
| `N` | namespace_menu | Switch namespace |
| `?` | help | Show help |
| `q` | quit | Hide window |
| `<C-c>` | close | Close window |
| `<C-h>` | back | Go back to previous view |

#### Describe View

| Key | Action | Description |
|-----|--------|-------------|
| `S` | toggle_secret | Toggle secret value visibility (Secret only) |
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

#### Help View

| Key | Action | Description |
|-----|--------|-------------|
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
