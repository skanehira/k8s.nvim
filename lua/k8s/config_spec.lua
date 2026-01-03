--- config_spec.lua - 設定管理のテスト

local config = require("k8s.config")

describe("config", function()
  describe("get_defaults", function()
    it("should return default configuration", function()
      local defaults = config.get_defaults()

      assert.equals(5000, defaults.refresh_interval)
      assert.equals(30000, defaults.timeout)
      assert.equals("default", defaults.default_namespace)
      assert.equals("Pod", defaults.default_kind)
      assert.is_false(defaults.transparent)
      assert(defaults.keymaps)
    end)

    it("should return a copy of defaults", function()
      local defaults1 = config.get_defaults()
      local defaults2 = config.get_defaults()

      defaults1.refresh_interval = 9999
      assert.equals(5000, defaults2.refresh_interval)
    end)
  end)

  describe("merge", function()
    it("should return defaults when no user config", function()
      local merged = config.merge(nil)

      assert.equals(5000, merged.refresh_interval)
    end)

    it("should merge user config with defaults", function()
      local merged = config.merge({
        refresh_interval = 10000,
      })

      assert.equals(10000, merged.refresh_interval)
      assert.equals(30000, merged.timeout) -- default preserved
    end)

    it("should deep merge nested config", function()
      local merged = config.merge({
        keymaps = {
          describe = { key = "K", desc = "Custom describe" },
        },
      })

      assert.equals("K", merged.keymaps.describe.key)
      assert.equals("Custom describe", merged.keymaps.describe.desc)
      assert.equals("D", merged.keymaps.delete.key) -- default preserved
    end)
  end)

  describe("validate", function()
    it("should return true for valid config", function()
      local valid, err = config.validate(config.get_defaults())

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false when refresh_interval is too low", function()
      local valid, err = config.validate({
        refresh_interval = 100,
        timeout = 30000,
      })

      assert.is_false(valid)
      assert.equals("refresh_interval must be a number >= 500", err)
    end)

    it("should return false when timeout is too low", function()
      local valid, err = config.validate({
        refresh_interval = 5000,
        timeout = 500,
      })

      assert.is_false(valid)
      assert.equals("timeout must be a number >= 1000", err)
    end)
  end)
end)
