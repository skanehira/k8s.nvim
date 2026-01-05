--- keymaps_spec.lua - キーマップ定義のテスト

local keymaps = require("k8s.views.keymaps")

describe("keymaps", function()
  describe("get_keymaps", function()
    it("should return keymaps for list view", function()
      local kms = keymaps.get_keymaps("pod_list")

      assert(#kms > 0)
      -- Check some expected keymaps
      local found_describe = false
      local found_logs = false
      for _, km in ipairs(kms) do
        if km.key == "d" and km.action == "describe" then
          found_describe = true
        end
        if km.key == "l" and km.action == "logs" then
          found_logs = true
        end
      end
      assert.is_true(found_describe)
      assert.is_true(found_logs)
    end)

    it("should return keymaps for describe view", function()
      local kms = keymaps.get_keymaps("pod_describe")

      assert(#kms > 0)
      local found_back = false
      local found_toggle_secret = false
      for _, km in ipairs(kms) do
        if km.key == "<C-h>" and km.action == "back" then
          found_back = true
        end
        if km.action == "toggle_secret" then
          found_toggle_secret = true
        end
      end
      assert.is_true(found_back)
      -- toggle_secret should NOT be in pod_describe
      assert.is_false(found_toggle_secret)
    end)

    it("should include toggle_secret keymap for secret_describe view", function()
      local kms = keymaps.get_keymaps("secret_describe")

      local found_toggle_secret = false
      for _, km in ipairs(kms) do
        if km.key == "S" and km.action == "toggle_secret" then
          found_toggle_secret = true
        end
      end
      assert.is_true(found_toggle_secret)
    end)

    it("should return keymaps for port_forward_list view", function()
      local kms = keymaps.get_keymaps("port_forward_list")

      assert(#kms > 0)
      local found_stop = false
      for _, km in ipairs(kms) do
        if km.key == "D" and km.action == "stop" then
          found_stop = true
        end
      end
      assert.is_true(found_stop)
    end)

    it("should return keymaps for help view", function()
      local kms = keymaps.get_keymaps("help")

      assert(#kms > 0)
      local found_quit = false
      for _, km in ipairs(kms) do
        if km.key == "q" and km.action == "quit" then
          found_quit = true
        end
      end
      assert.is_true(found_quit)
    end)
  end)

  describe("get_action_for_key", function()
    it("should return action for key in list view", function()
      assert.equals("describe", keymaps.get_action_for_key("pod_list", "d"))
      assert.equals("logs", keymaps.get_action_for_key("pod_list", "l"))
      assert.equals("quit", keymaps.get_action_for_key("pod_list", "q"))
    end)

    it("should return action for key in describe view", function()
      assert.equals("back", keymaps.get_action_for_key("pod_describe", "<C-h>"))
      assert.equals("toggle_secret", keymaps.get_action_for_key("secret_describe", "S"))
    end)

    it("should return nil for unknown key", function()
      assert.is_nil(keymaps.get_action_for_key("pod_list", "Z"))
    end)
  end)

  describe("requires_resource_selection", function()
    it("should return true for actions requiring resource", function()
      assert.is_true(keymaps.requires_resource_selection("select"))
      assert.is_true(keymaps.requires_resource_selection("describe"))
      assert.is_true(keymaps.requires_resource_selection("logs"))
      assert.is_true(keymaps.requires_resource_selection("exec"))
      assert.is_true(keymaps.requires_resource_selection("delete"))
    end)

    it("should return false for global actions", function()
      assert.is_false(keymaps.requires_resource_selection("quit"))
      assert.is_false(keymaps.requires_resource_selection("filter"))
      assert.is_false(keymaps.requires_resource_selection("refresh"))
      assert.is_false(keymaps.requires_resource_selection("help"))
    end)
  end)

  describe("get_base_view_type", function()
    it("should return list for list views", function()
      assert.equals("list", keymaps.get_base_view_type("pod_list"))
      assert.equals("list", keymaps.get_base_view_type("deployment_list"))
    end)

    it("should return describe for describe views", function()
      assert.equals("describe", keymaps.get_base_view_type("pod_describe"))
      assert.equals("describe", keymaps.get_base_view_type("secret_describe"))
    end)

    it("should return port_forward_list for port_forward_list", function()
      assert.equals("port_forward_list", keymaps.get_base_view_type("port_forward_list"))
    end)

    it("should return help for help", function()
      assert.equals("help", keymaps.get_base_view_type("help"))
    end)
  end)

  describe("resource-specific keymaps", function()
    it("should include logs for pod_list but not for deployment_list", function()
      local pod_kms = keymaps.get_keymaps("pod_list")
      local deploy_kms = keymaps.get_keymaps("deployment_list")

      local pod_has_logs = false
      local deploy_has_logs = false

      for _, km in ipairs(pod_kms) do
        if km.action == "logs" then
          pod_has_logs = true
        end
      end
      for _, km in ipairs(deploy_kms) do
        if km.action == "logs" then
          deploy_has_logs = true
        end
      end

      assert.is_true(pod_has_logs)
      assert.is_false(deploy_has_logs)
    end)

    it("should include scale for deployment_list but not for pod_list", function()
      local pod_kms = keymaps.get_keymaps("pod_list")
      local deploy_kms = keymaps.get_keymaps("deployment_list")

      local pod_has_scale = false
      local deploy_has_scale = false

      for _, km in ipairs(pod_kms) do
        if km.action == "scale" then
          pod_has_scale = true
        end
      end
      for _, km in ipairs(deploy_kms) do
        if km.action == "scale" then
          deploy_has_scale = true
        end
      end

      assert.is_false(pod_has_scale)
      assert.is_true(deploy_has_scale)
    end)

    it("should include debug only for pod_list", function()
      local pod_kms = keymaps.get_keymaps("pod_list")
      local deploy_kms = keymaps.get_keymaps("deployment_list")

      local pod_has_debug = false
      local deploy_has_debug = false

      for _, km in ipairs(pod_kms) do
        if km.action == "debug" then
          pod_has_debug = true
        end
      end
      for _, km in ipairs(deploy_kms) do
        if km.action == "debug" then
          deploy_has_debug = true
        end
      end

      assert.is_true(pod_has_debug)
      assert.is_false(deploy_has_debug)
    end)
  end)
end)
