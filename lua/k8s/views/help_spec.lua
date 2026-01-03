--- help_spec.lua - ヘルプビューのテスト

local help = require("k8s.views.help")

describe("help", function()
  describe("format_keymap_lines", function()
    it("should format keymaps into lines", function()
      local keymap_defs = {
        { key = "<CR>", action = "select", desc = "Select" },
        { key = "d", action = "describe", desc = "Describe" },
        { key = "l", action = "logs", desc = "Logs" },
        { key = "e", action = "exec", desc = "Exec" },
      }

      local lines = help.format_keymap_lines(keymap_defs, 4) -- 4 items per line

      assert.equals(1, #lines)
      -- Check that all keys and descriptions are present
      assert.matches("<CR>", lines[1])
      assert.matches("Select", lines[1])
      assert.matches("d", lines[1])
      assert.matches("Describe", lines[1])
    end)

    it("should wrap to multiple lines when needed", function()
      local keymap_defs = {
        { key = "a", action = "action1", desc = "Action1" },
        { key = "b", action = "action2", desc = "Action2" },
        { key = "c", action = "action3", desc = "Action3" },
        { key = "d", action = "action4", desc = "Action4" },
        { key = "e", action = "action5", desc = "Action5" },
      }

      local lines = help.format_keymap_lines(keymap_defs, 3) -- 3 items per line

      assert.equals(2, #lines)
    end)

    it("should handle empty keymaps", function()
      local lines = help.format_keymap_lines({}, 4)

      assert.equals(0, #lines)
    end)
  end)

  describe("create_content", function()
    it("should create help content for list view", function()
      local lines = help.create_content("pod_list")

      assert(#lines > 0)
      -- Should have title
      assert.equals("Keymaps:", lines[1])
      -- Should have keymap entries
      assert(#lines > 2)
    end)

    it("should create help content for describe view", function()
      local lines = help.create_content("pod_describe")

      assert(#lines > 0)
      assert.equals("Keymaps:", lines[1])
    end)

    it("should create help content for port_forward_list view", function()
      local lines = help.create_content("port_forward_list")

      assert(#lines > 0)
      assert.equals("Keymaps:", lines[1])
    end)
  end)
end)
