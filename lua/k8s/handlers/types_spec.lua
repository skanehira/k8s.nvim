--- types_spec.lua - ハンドラー型定義のテスト

local types = require("k8s.handlers.types")

describe("types", function()
  describe("validate_callbacks", function()
    it("should return true when all required fields exist", function()
      local callbacks = {
        render_footer = function() end,
        fetch_and_render = function() end,
      }

      local valid, missing = types.validate_callbacks(callbacks, { "render_footer", "fetch_and_render" })

      assert.is_true(valid)
      assert.is_nil(missing)
    end)

    it("should return false when required field is missing", function()
      local callbacks = {
        render_footer = function() end,
      }

      local valid, missing = types.validate_callbacks(callbacks, { "render_footer", "fetch_and_render" })

      assert.is_false(valid)
      assert.equals("fetch_and_render", missing)
    end)

    it("should return true for empty requirements", function()
      local callbacks = {}

      local valid, missing = types.validate_callbacks(callbacks, {})

      assert.is_true(valid)
      assert.is_nil(missing)
    end)
  end)

  describe("get_callback_requirements", function()
    it("should return requirements for handle_back", function()
      local reqs = types.get_callback_requirements("handle_back")

      assert.is_table(reqs)
      assert.equals(2, #reqs)
      assert.is_true(vim.tbl_contains(reqs, "render_footer"))
      assert.is_true(vim.tbl_contains(reqs, "fetch_and_render"))
    end)

    it("should return requirements for handle_describe", function()
      local reqs = types.get_callback_requirements("handle_describe")

      assert.is_table(reqs)
      assert.equals(2, #reqs)
      assert.is_true(vim.tbl_contains(reqs, "setup_keymaps_for_window"))
      assert.is_true(vim.tbl_contains(reqs, "get_footer_keymaps"))
    end)

    it("should return empty for handlers with no requirements", function()
      local reqs = types.get_callback_requirements("handle_logs")

      assert.is_table(reqs)
      assert.equals(0, #reqs)
    end)

    it("should return empty for unknown handler", function()
      local reqs = types.get_callback_requirements("unknown_handler")

      assert.is_table(reqs)
      assert.equals(0, #reqs)
    end)

    it("should return requirements for handle_resource_menu", function()
      local reqs = types.get_callback_requirements("handle_resource_menu")

      assert.is_table(reqs)
      assert.equals(3, #reqs)
      assert.is_true(vim.tbl_contains(reqs, "setup_keymaps_for_window"))
      assert.is_true(vim.tbl_contains(reqs, "get_footer_keymaps"))
      assert.is_true(vim.tbl_contains(reqs, "fetch_and_render"))
    end)
  end)
end)
