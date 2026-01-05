# k8s.nvim

A Neovim plugin for managing Kubernetes resources.

<table>
  <tr>
    <td><img src="https://i.gyazo.com/e50276c903e45ec2995d41f29f0e1d03.png" alt="Image from Gyazo"></a></td>
    <td><img src="https://i.gyazo.com/91914f58f33455045d90318d9faa6b68.png" alt="Image from Gyazo"></a></td>
  </tr>
  <tr>
    <td><img src="https://i.gyazo.com/db6633005503eb3168e2cac63af093ea.png" alt="Image from Gyazo"></a></td>
    <td><img src="https://i.gyazo.com/f673d9b3739a8b531a1f943345af1b52.png" alt="Image from Gyazo"></a></td>
  </tr>
</table>

## Features

- Browse and manage Kubernetes resources (Pod, Deployment, Service, ConfigMap, Secret, Node, Namespace)
- View resource details with `kubectl describe`
- Execute commands in pods, view logs
- Port forwarding with connection management
- Scale and restart deployments
- Filter resources, switch contexts and namespaces

## Requirements

- Neovim >= 0.10.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) configured with cluster access
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## Installation

```lua
-- lazy.nvim
{
  "skanehira/k8s.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  opts = {},
}
```

## Usage

```vim
:K8s              " Toggle window
:K8s pods         " Open with Pod view
:K8s deployments  " Open with Deployment view
```

For detailed documentation, see `:help k8s`.

## Keymap Customization

Keymaps are defined per view type. You can customize them in your setup:

```lua
{
  "skanehira/k8s.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    keymaps = {
      -- Global keymaps (all views)
      global = {
        quit = { key = "Q", desc = "Hide" },
      },
      -- Pod list view
      pod_list = {
        describe = { key = "K", desc = "Describe" },
      },
      -- Deployment list view
      deployment_list = {
        scale = { key = "S", desc = "Scale" },
      },
    },
  },
}
```

Available view types: `pod_list`, `deployment_list`, `service_list`, `secret_describe`, etc.

## License

MIT
