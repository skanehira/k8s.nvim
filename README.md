# k8s.nvim

A Neovim plugin for managing Kubernetes resources.

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

## License

MIT
