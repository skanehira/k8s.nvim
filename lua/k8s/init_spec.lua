--- init_spec.lua - k8s.nvim メインモジュールのテスト

local k8s = require("k8s")

describe("k8s", function()
  local state

  before_each(function()
    state = require("k8s.state")
    state.reset()
  end)

  describe("get_state", function()
    it("should return current state", function()
      local current = k8s.get_state()

      assert.is_false(current.setup_done)
      assert.is_nil(current.config)
      assert.is_nil(current.context)
      assert.equals("default", current.namespace)
    end)
  end)

  describe("is_setup_done", function()
    it("should return false before setup", function()
      assert.is_false(k8s.is_setup_done())
    end)
  end)

  describe("create_highlights", function()
    it("should return highlight definitions", function()
      local highlights = k8s.create_highlights()

      assert(highlights.K8sStatusRunning)
      assert(highlights.K8sStatusPending)
      assert(highlights.K8sStatusError)
      assert(highlights.K8sHeader)
      assert(highlights.K8sFooter)
      assert(highlights.K8sTableHeader)
    end)
  end)

  describe("get_default_kind", function()
    it("should return Pod", function()
      assert.equals("Pod", k8s.get_default_kind())
    end)
  end)

  describe("get_resource_kind_from_command", function()
    it("should return Pod for pods", function()
      assert.equals("Pod", k8s.get_resource_kind_from_command("pods"))
    end)

    it("should return Deployment for deployments", function()
      assert.equals("Deployment", k8s.get_resource_kind_from_command("deployments"))
    end)

    it("should return Service for services", function()
      assert.equals("Service", k8s.get_resource_kind_from_command("services"))
    end)

    it("should return nil for unknown command", function()
      assert.is_nil(k8s.get_resource_kind_from_command("unknown"))
    end)
  end)

  describe("parse_command_args", function()
    it("should return toggle for empty args", function()
      local cmd, args = k8s.parse_command_args({})

      assert.equals("toggle", cmd)
      assert.is_nil(args)
    end)

    it("should return open for open command", function()
      local cmd, args = k8s.parse_command_args({ "open" })

      assert.equals("open", cmd)
      assert.is_nil(args)
    end)

    it("should return close for close command", function()
      local cmd, args = k8s.parse_command_args({ "close" })

      assert.equals("close", cmd)
      assert.is_nil(args)
    end)

    it("should return context with name", function()
      local cmd, args = k8s.parse_command_args({ "context", "minikube" })

      assert.equals("context", cmd)
      assert(args)
      assert.equals("minikube", args.name)
    end)

    it("should return namespace with name", function()
      local cmd, args = k8s.parse_command_args({ "namespace", "kube-system" })

      assert.equals("namespace", cmd)
      assert(args)
      assert.equals("kube-system", args.name)
    end)

    it("should return portforwards for portforwards command", function()
      local cmd, args = k8s.parse_command_args({ "portforwards" })

      assert.equals("portforwards", cmd)
      assert.is_nil(args)
    end)

    it("should return open_resource for pods command", function()
      local cmd, args = k8s.parse_command_args({ "pods" })

      assert.equals("open_resource", cmd)
      assert(args)
      assert.equals("Pod", args.kind)
    end)

    it("should return open_resource for deployments command", function()
      local cmd, args = k8s.parse_command_args({ "deployments" })

      assert.equals("open_resource", cmd)
      assert(args)
      assert.equals("Deployment", args.kind)
    end)

    it("should return toggle for unknown command", function()
      local cmd, args = k8s.parse_command_args({ "unknown" })

      assert.equals("toggle", cmd)
      assert.is_nil(args)
    end)
  end)

  describe("check_kubectl", function()
    it("should return boolean", function()
      local result = k8s.check_kubectl()

      assert.is_boolean(result)
    end)
  end)
end)
