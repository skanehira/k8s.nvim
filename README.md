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
    describe = "d",
    delete = "D",
    logs = "l",
    exec = "e",
    scale = "s",
    restart = "X",
    port_forward = "p",
    port_forward_list = "F",
    filter = "/",
    refresh = "r",
    context_menu = "C",
    namespace_menu = "N",
    resource_menu = "R",
    toggle_secret = "S",
    help = "?",
    quit = "q",
    back = "<C-h>",
    select = "<CR>",
  },
})
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:K8s` | Open k8s.nvim with default resource kind |
| `:K8s <kind>` | Open with specific resource kind (e.g., `:K8s Pod`) |
| `:K8sClose` | Close k8s.nvim window |
| `:K8sContext <name>` | Switch to specified context |
| `:K8sNamespace <name>` | Switch to specified namespace |

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
| `q` | quit | Close window |
| `<C-h>` | back | Go back to previous view |

#### Describe View

| Key | Action | Description |
|-----|--------|-------------|
| `l` | logs | View pod logs (Pod only) |
| `e` | exec | Execute shell in pod (Pod only) |
| `D` | delete | Delete resource |
| `<C-h>` | back | Go back to list view |
| `q` | quit | Close window |

#### Port Forward List View

| Key | Action | Description |
|-----|--------|-------------|
| `D` | stop | Stop selected port forward |
| `<C-h>` | back | Go back to previous view |
| `q` | quit | Close window |

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
