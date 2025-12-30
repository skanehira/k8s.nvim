--- describe_spec.lua - describe Viewのテスト

local describe_view = require("k8s.ui.views.describe")

describe("describe_view", function()
  describe("get_default_keymaps", function()
    it("should return keymap definitions", function()
      local keymaps = describe_view.get_default_keymaps()

      assert.is.Not.Nil(keymaps["<C-h>"])
      assert.equals("back", keymaps["<C-h>"])

      assert.is.Not.Nil(keymaps["l"])
      assert.equals("logs", keymaps["l"])

      assert.is.Not.Nil(keymaps["e"])
      assert.equals("exec", keymaps["e"])

      assert.is.Not.Nil(keymaps["D"])
      assert.equals("delete", keymaps["D"])

      assert.is.Not.Nil(keymaps["q"])
      assert.equals("quit", keymaps["q"])
    end)
  end)

  describe("get_action_for_key", function()
    it("should return action name for valid key", function()
      local action = describe_view.get_action_for_key("<C-h>")
      assert.equals("back", action)
    end)

    it("should return nil for unmapped key", function()
      local action = describe_view.get_action_for_key("z")
      assert.is_nil(action)
    end)
  end)

  describe("format_header_info", function()
    it("should format header with kind and name", function()
      local info = describe_view.format_header_info("Pod", "nginx-abc123", "default")

      assert.equals("Pod", info.kind)
      assert.equals("nginx-abc123", info.name)
      assert.equals("default", info.namespace)
    end)
  end)

  describe("get_filetype", function()
    it("should return yaml filetype", function()
      assert.equals("yaml", describe_view.get_filetype())
    end)
  end)

  describe("can_perform_action", function()
    it("should allow logs on Pod", function()
      assert.is_true(describe_view.can_perform_action("Pod", "logs"))
    end)

    it("should allow exec on Pod", function()
      assert.is_true(describe_view.can_perform_action("Pod", "exec"))
    end)

    it("should not allow logs on Deployment", function()
      assert.is_false(describe_view.can_perform_action("Deployment", "logs"))
    end)

    it("should not allow exec on Service", function()
      assert.is_false(describe_view.can_perform_action("Service", "exec"))
    end)

    it("should allow delete on any resource", function()
      -- delete is always allowed (confirmation handles it)
      assert.is_true(describe_view.can_perform_action("Pod", "delete"))
      assert.is_true(describe_view.can_perform_action("Deployment", "delete"))
      assert.is_true(describe_view.can_perform_action("Service", "delete"))
    end)
  end)
end)
