--- config_spec.lua - 設定管理のテスト

local config = require("k8s.config")

describe("config", function()
  describe("get_defaults", function()
    it("should return default configuration", function()
      local defaults = config.get_defaults()

      assert.equals(30000, defaults.timeout)
      assert.equals("default", defaults.default_namespace)
      assert.equals("Pod", defaults.default_kind)
      assert.is_false(defaults.transparent)
      assert(defaults.keymaps)
    end)

    it("should return keymaps with view-specific structure", function()
      local defaults = config.get_defaults()

      -- Check global keymaps
      assert(defaults.keymaps.global)
      assert.equals("q", defaults.keymaps.global.quit.key)
      assert.equals("<C-c>", defaults.keymaps.global.close.key)
      assert.equals("<C-h>", defaults.keymaps.global.back.key)
      assert.equals("?", defaults.keymaps.global.help.key)

      -- Check pod_list keymaps (resource-specific)
      assert(defaults.keymaps.pod_list)
      assert.equals("d", defaults.keymaps.pod_list.describe.key)
      assert.equals("D", defaults.keymaps.pod_list.delete.key)
      assert.equals("l", defaults.keymaps.pod_list.logs.key)

      -- Check deployment_list keymaps (different actions)
      assert(defaults.keymaps.deployment_list)
      assert.equals("s", defaults.keymaps.deployment_list.scale.key)
      assert.equals("X", defaults.keymaps.deployment_list.restart.key)
      assert.is_nil(defaults.keymaps.deployment_list.logs) -- deployment doesn't have logs

      -- Check secret_describe keymaps
      assert(defaults.keymaps.secret_describe)
      assert.equals("S", defaults.keymaps.secret_describe.toggle_secret.key)

      -- Check port_forward_list keymaps
      assert(defaults.keymaps.port_forward_list)
      assert.equals("D", defaults.keymaps.port_forward_list.stop.key)

      -- Check help keymaps (empty, only uses common)
      assert(defaults.keymaps.help)
    end)

    it("should return a copy of defaults", function()
      local defaults1 = config.get_defaults()
      local defaults2 = config.get_defaults()

      defaults1.timeout = 9999
      assert.equals(30000, defaults2.timeout)
    end)
  end)

  describe("merge", function()
    it("should return defaults when no user config", function()
      local merged = config.merge(nil)

      assert.equals(30000, merged.timeout)
    end)

    it("should merge user config with defaults", function()
      local merged = config.merge({
        timeout = 60000,
      })

      assert.equals(60000, merged.timeout)
      assert.equals("default", merged.default_namespace) -- default preserved
    end)

    it("should deep merge view-specific keymaps", function()
      local merged = config.merge({
        keymaps = {
          pod_list = {
            describe = { key = "K", desc = "Custom describe" },
          },
        },
      })

      -- Custom keymap applied
      assert.equals("K", merged.keymaps.pod_list.describe.key)
      assert.equals("Custom describe", merged.keymaps.pod_list.describe.desc)

      -- Other keymaps preserved
      assert.equals("D", merged.keymaps.pod_list.delete.key)
      assert.equals("q", merged.keymaps.global.quit.key)
    end)

    it("should deep merge global keymaps", function()
      local merged = config.merge({
        keymaps = {
          global = {
            quit = { key = "Q", desc = "Custom quit" },
          },
        },
      })

      -- Custom keymap applied
      assert.equals("Q", merged.keymaps.global.quit.key)

      -- Other global keymaps preserved
      assert.equals("<C-c>", merged.keymaps.global.close.key)
    end)
  end)

  describe("validate", function()
    it("should return true for valid config", function()
      local valid, err = config.validate(config.get_defaults())

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false when timeout is too low", function()
      local valid, err = config.validate({
        timeout = 500,
      })

      assert.is_false(valid)
      assert.equals("timeout must be a number >= 1000", err)
    end)
  end)
end)
