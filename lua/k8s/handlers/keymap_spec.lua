--- keymap_spec.lua - キーマップモジュールのテスト

describe("keymap", function()
  local keymap

  before_each(function()
    package.loaded["k8s.handlers.keymap"] = nil
    package.loaded["k8s.core.global_state"] = nil
    keymap = require("k8s.handlers.keymap")
  end)

  describe("get_keymap_definitions", function()
    it("should return keymap definitions", function()
      local keymaps = keymap.get_keymap_definitions()
      assert.is.Not.Nil(keymaps)
      assert.is.Not.Nil(keymaps.describe)
      assert.equals("d", keymaps.describe.key)
      assert.equals("describe", keymaps.describe.action)
    end)

    it("should contain all expected actions", function()
      local keymaps = keymap.get_keymap_definitions()
      local expected_actions = {
        "describe",
        "delete",
        "logs",
        "exec",
        "scale",
        "restart",
        "port_forward",
        "port_forward_list",
        "filter",
        "refresh",
        "resource_menu",
        "context_menu",
        "namespace_menu",
        "toggle_secret",
        "logs_previous",
        "help",
        "quit",
        "back",
        "select",
      }
      for _, action in ipairs(expected_actions) do
        assert.is.Not.Nil(keymaps[action], "Expected action: " .. action)
      end
    end)
  end)

  describe("get_current_view_type", function()
    it("should return nil when view_stack is nil", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack(nil)
      assert.is_nil(keymap.get_current_view_type())
    end)

    it("should return current view type", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack({ { type = "list", kind = "Pod" } })
      assert.equals("list", keymap.get_current_view_type())
    end)

    it("should return describe view type", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack({
        { type = "list", kind = "Pod" },
        { type = "describe", resource = { name = "test" } },
      })
      assert.equals("describe", keymap.get_current_view_type())
    end)
  end)

  describe("is_action_allowed", function()
    it("should return false when no view_stack", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack(nil)
      assert.is_false(keymap.is_action_allowed("describe"))
    end)

    it("should return true for allowed actions in list view", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack({ { type = "list", kind = "Pod" } })

      assert.is_true(keymap.is_action_allowed("describe"))
      assert.is_true(keymap.is_action_allowed("delete"))
      assert.is_true(keymap.is_action_allowed("refresh"))
      assert.is_true(keymap.is_action_allowed("filter"))
    end)

    it("should return false for disallowed actions in describe view", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack({
        { type = "list", kind = "Pod" },
        { type = "describe", resource = { name = "test" } },
      })

      -- describe view doesn't allow refresh, filter, etc.
      assert.is_false(keymap.is_action_allowed("refresh"))
      assert.is_false(keymap.is_action_allowed("filter"))
      assert.is_false(keymap.is_action_allowed("resource_menu"))
    end)

    it("should return true for allowed actions in describe view", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack({
        { type = "list", kind = "Pod" },
        { type = "describe", resource = { name = "test" } },
      })

      assert.is_true(keymap.is_action_allowed("back"))
      assert.is_true(keymap.is_action_allowed("logs"))
      assert.is_true(keymap.is_action_allowed("exec"))
      assert.is_true(keymap.is_action_allowed("quit"))
    end)

    it("should return true for stop action in port_forward_list view", function()
      local global_state = require("k8s.core.global_state")
      global_state.set_view_stack({
        { type = "list", kind = "Pod" },
        { type = "port_forward_list" },
      })

      assert.is_true(keymap.is_action_allowed("stop"))
      assert.is_true(keymap.is_action_allowed("back"))
      assert.is_false(keymap.is_action_allowed("delete")) -- delete is not stop
    end)
  end)

  describe("get_footer_keymaps", function()
    it("should return list keymaps for list view", function()
      local keymaps = keymap.get_footer_keymaps("list")
      assert.is.Not.Nil(keymaps)
      assert.truthy(#keymaps > 0)

      -- Check that describe is included
      local has_describe = false
      for _, km in ipairs(keymaps) do
        if km.action == "describe" then
          has_describe = true
          break
        end
      end
      assert.is_true(has_describe)
    end)

    it("should return describe keymaps for describe view", function()
      local keymaps = keymap.get_footer_keymaps("describe")
      assert.is.Not.Nil(keymaps)

      -- Check that back is included
      local has_back = false
      for _, km in ipairs(keymaps) do
        if km.action == "back" then
          has_back = true
          break
        end
      end
      assert.is_true(has_back)
    end)

    it("should filter by resource capabilities when kind is provided", function()
      -- Pod has logs capability
      local pod_keymaps = keymap.get_footer_keymaps("list", "Pod")
      local has_logs = false
      for _, km in ipairs(pod_keymaps) do
        if km.action == "logs" then
          has_logs = true
          break
        end
      end
      assert.is_true(has_logs)

      -- ConfigMap does not have logs capability
      local cm_keymaps = keymap.get_footer_keymaps("list", "ConfigMap")
      has_logs = false
      for _, km in ipairs(cm_keymaps) do
        if km.action == "logs" then
          has_logs = true
          break
        end
      end
      assert.is_false(has_logs)
    end)
  end)
end)
