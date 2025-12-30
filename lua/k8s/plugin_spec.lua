--- plugin_spec.lua - プラグインコマンド定義のテスト

local plugin = require("k8s.plugin")

describe("plugin", function()
  describe("get_commands", function()
    it("should return command definitions", function()
      local commands = plugin.get_commands()

      assert.is_table(commands)
      assert(#commands > 0)
    end)

    it("should include K8s command", function()
      local commands = plugin.get_commands()

      local has_k8s = false
      for _, cmd in ipairs(commands) do
        if cmd.name == "K8s" then
          has_k8s = true
          break
        end
      end

      assert.is_true(has_k8s)
    end)
  end)

  describe("get_plug_mappings", function()
    it("should return plug mappings", function()
      local mappings = plugin.get_plug_mappings()

      assert.is_table(mappings)
      assert(#mappings > 0)
    end)

    it("should include toggle mapping", function()
      local mappings = plugin.get_plug_mappings()

      local has_toggle = false
      for _, m in ipairs(mappings) do
        if m.name:find("toggle") then
          has_toggle = true
          break
        end
      end

      assert.is_true(has_toggle)
    end)
  end)

  describe("get_command_completions", function()
    it("should return completions for K8s command", function()
      local completions = plugin.get_command_completions()

      assert.is_table(completions)
      assert(vim.tbl_contains(completions, "open"))
      assert(vim.tbl_contains(completions, "close"))
      assert(vim.tbl_contains(completions, "pods"))
    end)
  end)

  describe("parse_command", function()
    it("should parse K8s command", function()
      local action, args = plugin.parse_command("pods")

      assert.equals("open_resource", action)
      assert.equals("Pod", args.kind)
    end)

    it("should parse K8s open command", function()
      local action = plugin.parse_command("open")

      assert.equals("open", action)
    end)

    it("should default to toggle", function()
      local action = plugin.parse_command("")

      assert.equals("toggle", action)
    end)
  end)

  describe("get_subcommand_list", function()
    it("should return list of subcommands", function()
      local subcommands = plugin.get_subcommand_list()

      assert.is_table(subcommands)
      assert(vim.tbl_contains(subcommands, "pods"))
      assert(vim.tbl_contains(subcommands, "deployments"))
    end)
  end)
end)
