--- init_spec.lua - メインモジュールのテスト

local init = require("k8s.init")

describe("init", function()
  describe("get_state", function()
    it("should return current state", function()
      local state = init.get_state()

      assert.is_table(state)
      assert.is_false(state.setup_done)
    end)
  end)

  describe("is_setup_done", function()
    it("should return false before setup", function()
      assert.is_false(init.is_setup_done())
    end)
  end)

  describe("create_highlights", function()
    it("should return highlight definitions", function()
      local highlights = init.create_highlights()

      assert.is_table(highlights)
      assert.is_table(highlights.K8sStatusRunning)
      assert.is_table(highlights.K8sStatusPending)
      assert.is_table(highlights.K8sStatusError)
    end)

    it("should have correct colors for running status", function()
      local highlights = init.create_highlights()

      assert(highlights.K8sStatusRunning.fg)
    end)
  end)

  describe("get_default_kind", function()
    it("should return Pod as default", function()
      assert.equals("Pod", init.get_default_kind())
    end)
  end)

  describe("parse_command_args", function()
    it("should parse open command", function()
      local cmd = init.parse_command_args({ "open" })

      assert.equals("open", cmd)
    end)

    it("should parse close command", function()
      local cmd = init.parse_command_args({ "close" })

      assert.equals("close", cmd)
    end)

    it("should parse pods command", function()
      local cmd, args = init.parse_command_args({ "pods" })

      assert.equals("open_resource", cmd)
      assert.equals("Pod", args.kind)
    end)

    it("should parse deployments command", function()
      local cmd, args = init.parse_command_args({ "deployments" })

      assert.equals("open_resource", cmd)
      assert.equals("Deployment", args.kind)
    end)

    it("should parse context command with name", function()
      local cmd, args = init.parse_command_args({ "context", "minikube" })

      assert.equals("context", cmd)
      assert.equals("minikube", args.name)
    end)

    it("should parse namespace command with name", function()
      local cmd, args = init.parse_command_args({ "namespace", "kube-system" })

      assert.equals("namespace", cmd)
      assert.equals("kube-system", args.name)
    end)

    it("should default to toggle for empty args", function()
      local cmd = init.parse_command_args({})

      assert.equals("toggle", cmd)
    end)
  end)

  describe("get_resource_kind_from_command", function()
    it("should map pods to Pod", function()
      assert.equals("Pod", init.get_resource_kind_from_command("pods"))
    end)

    it("should map deployments to Deployment", function()
      assert.equals("Deployment", init.get_resource_kind_from_command("deployments"))
    end)

    it("should map services to Service", function()
      assert.equals("Service", init.get_resource_kind_from_command("services"))
    end)

    it("should map nodes to Node", function()
      assert.equals("Node", init.get_resource_kind_from_command("nodes"))
    end)

    it("should return nil for unknown command", function()
      assert.is_nil(init.get_resource_kind_from_command("unknown"))
    end)
  end)

  describe("get_keymap_definitions", function()
    it("should return all keymap definitions", function()
      local keymaps = init.get_keymap_definitions()

      assert.is_table(keymaps)
      assert.is.Not.Nil(keymaps.describe)
      assert.is.Not.Nil(keymaps.delete)
      assert.is.Not.Nil(keymaps.logs)
      assert.is.Not.Nil(keymaps.exec)
      assert.is.Not.Nil(keymaps.scale)
      assert.is.Not.Nil(keymaps.restart)
      assert.is.Not.Nil(keymaps.refresh)
      assert.is.Not.Nil(keymaps.filter)
      assert.is.Not.Nil(keymaps.help)
      assert.is.Not.Nil(keymaps.quit)
      assert.is.Not.Nil(keymaps.back)
      assert.is.Not.Nil(keymaps.select)
    end)

    it("should have correct keymap structure", function()
      local keymaps = init.get_keymap_definitions()

      assert.equals("d", keymaps.describe.key)
      assert.equals("describe", keymaps.describe.action)
    end)
  end)

  describe("get_footer_keymaps", function()
    it("should return keymaps for footer display", function()
      local keymaps = init.get_footer_keymaps("list")

      assert.is_table(keymaps)
      -- list view should have common keymaps
      local has_describe = false
      for _, km in ipairs(keymaps) do
        if km.action == "describe" then
          has_describe = true
        end
      end
      assert.is_true(has_describe)
    end)

    it("should return different keymaps for describe view", function()
      local keymaps = init.get_footer_keymaps("describe")

      assert.is_table(keymaps)
      -- describe view should have back keymap
      local has_back = false
      for _, km in ipairs(keymaps) do
        if km.action == "back" then
          has_back = true
        end
      end
      assert.is_true(has_back)
    end)
  end)
end)
