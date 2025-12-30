--- help_spec.lua - ヘルプViewのテスト

local help = require("k8s.ui.views.help")

describe("help", function()
  describe("get_keymaps_for_view", function()
    it("should return keymaps for resource_list view", function()
      local keymaps = help.get_keymaps_for_view("resource_list")

      assert(#keymaps > 0)
      -- Check some expected keymaps
      local found_describe = false
      local found_logs = false
      for _, km in ipairs(keymaps) do
        if km.key == "d" and km.action == "Describe" then
          found_describe = true
        end
        if km.key == "l" and km.action == "Logs" then
          found_logs = true
        end
      end
      assert.is_true(found_describe)
      assert.is_true(found_logs)
    end)

    it("should return keymaps for describe view", function()
      local keymaps = help.get_keymaps_for_view("describe")

      assert(#keymaps > 0)
      local found_back = false
      for _, km in ipairs(keymaps) do
        if km.key == "<C-h>" and km.action == "Back" then
          found_back = true
        end
      end
      assert.is_true(found_back)
    end)

    it("should return keymaps for port_forward_list view", function()
      local keymaps = help.get_keymaps_for_view("port_forward_list")

      assert(#keymaps > 0)
      local found_stop = false
      for _, km in ipairs(keymaps) do
        if km.key == "D" and km.action == "Stop" then
          found_stop = true
        end
      end
      assert.is_true(found_stop)
    end)
  end)

  describe("format_keymap_lines", function()
    it("should format keymaps into lines", function()
      local keymaps = {
        { key = "<CR>", action = "Select" },
        { key = "d", action = "Describe" },
        { key = "l", action = "Logs" },
        { key = "e", action = "Exec" },
      }

      local lines = help.format_keymap_lines(keymaps, 4) -- 4 items per line

      assert.equals(1, #lines)
      -- Check that all keys and actions are present (with padding for alignment)
      assert.matches("<CR>", lines[1])
      assert.matches("Select", lines[1])
      assert.matches("d", lines[1])
      assert.matches("Describe", lines[1])
      assert.matches("l", lines[1])
      assert.matches("Logs", lines[1])
      assert.matches("e", lines[1])
      assert.matches("Exec", lines[1])
    end)

    it("should wrap to multiple lines when needed", function()
      local keymaps = {
        { key = "a", action = "Action1" },
        { key = "b", action = "Action2" },
        { key = "c", action = "Action3" },
        { key = "d", action = "Action4" },
        { key = "e", action = "Action5" },
      }

      local lines = help.format_keymap_lines(keymaps, 3) -- 3 items per line

      assert.equals(2, #lines)
    end)
  end)

  describe("get_help_title", function()
    it("should return correct title", function()
      assert.equals("Keymaps:", help.get_help_title())
    end)
  end)

  describe("create_help_content", function()
    it("should create help content from keymap definitions", function()
      local keymaps = {
        describe = { key = "d", action = "describe", desc = "Describe" },
        logs = { key = "l", action = "logs", desc = "Logs" },
        quit = { key = "q", action = "quit", desc = "Quit" },
      }

      local lines = help.create_help_content(keymaps)

      assert(#lines > 0)
      -- Should have title
      assert.equals("Keymaps:", lines[1])
    end)

    it("should handle empty keymaps", function()
      local lines = help.create_help_content({})

      assert(#lines > 0)
      assert.equals("Keymaps:", lines[1])
    end)
  end)
end)
