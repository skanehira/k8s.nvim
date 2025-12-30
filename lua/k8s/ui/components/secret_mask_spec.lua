--- secret_mask_spec.lua - Secretマスクコンポーネントのテスト

local secret_mask = require("k8s.ui.components.secret_mask")

describe("secret_mask", function()
  describe("create_state", function()
    it("should create initial state with masked true", function()
      local state = secret_mask.create_state()
      assert.is_true(state.masked)
    end)
  end)

  describe("toggle", function()
    it("should toggle masked state from true to false", function()
      local state = secret_mask.create_state()
      secret_mask.toggle(state)
      assert.is_false(state.masked)
    end)

    it("should toggle masked state from false to true", function()
      local state = secret_mask.create_state()
      state.masked = false
      secret_mask.toggle(state)
      assert.is_true(state.masked)
    end)
  end)

  describe("is_masked", function()
    it("should return true when masked", function()
      local state = secret_mask.create_state()
      assert.is_true(secret_mask.is_masked(state))
    end)

    it("should return false when not masked", function()
      local state = secret_mask.create_state()
      state.masked = false
      assert.is_false(secret_mask.is_masked(state))
    end)
  end)

  describe("mask_value", function()
    it("should return masked string when masked", function()
      local state = secret_mask.create_state()
      local result = secret_mask.mask_value(state, "secret-password-123")
      assert.equals("********", result)
    end)

    it("should return original value when not masked", function()
      local state = secret_mask.create_state()
      state.masked = false
      local result = secret_mask.mask_value(state, "secret-password-123")
      assert.equals("secret-password-123", result)
    end)

    it("should return empty string for nil value when masked", function()
      local state = secret_mask.create_state()
      local result = secret_mask.mask_value(state, nil)
      assert.equals("", result)
    end)

    it("should return empty string for nil value when not masked", function()
      local state = secret_mask.create_state()
      state.masked = false
      local result = secret_mask.mask_value(state, nil)
      assert.equals("", result)
    end)
  end)

  describe("mask_secret_data", function()
    it("should mask all data values when masked", function()
      local state = secret_mask.create_state()
      local data = {
        username = "admin",
        password = "secret123",
        token = "abc-xyz-123",
      }

      local result = secret_mask.mask_secret_data(state, data)

      assert.equals("********", result.username)
      assert.equals("********", result.password)
      assert.equals("********", result.token)
    end)

    it("should return original data when not masked", function()
      local state = secret_mask.create_state()
      state.masked = false
      local data = {
        username = "admin",
        password = "secret123",
      }

      local result = secret_mask.mask_secret_data(state, data)

      assert.equals("admin", result.username)
      assert.equals("secret123", result.password)
    end)

    it("should return empty table for nil data", function()
      local state = secret_mask.create_state()
      local result = secret_mask.mask_secret_data(state, nil)
      assert.same({}, result)
    end)

    it("should handle empty table", function()
      local state = secret_mask.create_state()
      local result = secret_mask.mask_secret_data(state, {})
      assert.same({}, result)
    end)
  end)

  describe("get_status_text", function()
    it("should return 'Hidden' when masked", function()
      local state = secret_mask.create_state()
      assert.equals("Hidden", secret_mask.get_status_text(state))
    end)

    it("should return 'Visible' when not masked", function()
      local state = secret_mask.create_state()
      state.masked = false
      assert.equals("Visible", secret_mask.get_status_text(state))
    end)
  end)
end)
