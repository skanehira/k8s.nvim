--- keymap_binder_spec.lua - キーマップバインダーのテスト

local keymap_binder = require("k8s.ui.nui.keymap_binder")

describe("keymap_binder", function()
  describe("create_keymap_config", function()
    it("should create keymap config from definition", function()
      local def = {
        key = "d",
        action = "describe",
        desc = "Show resource details",
      }

      local config = keymap_binder.create_keymap_config(def)

      assert.equals("d", config.key)
      assert.equals("n", config.mode)
      assert.is_table(config.opts)
      assert.equals("Show resource details", config.opts.desc)
      assert.is_true(config.opts.noremap)
      assert.is_true(config.opts.silent)
    end)

    it("should support custom mode", function()
      local def = {
        key = "<CR>",
        action = "select",
        mode = "v",
      }

      local config = keymap_binder.create_keymap_config(def)

      assert.equals("v", config.mode)
    end)
  end)

  describe("validate_keymap_definition", function()
    it("should return true for valid definition", function()
      local def = {
        key = "d",
        action = "describe",
      }

      local valid, err = keymap_binder.validate_keymap_definition(def)

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false when key is missing", function()
      local def = {
        action = "describe",
      }

      local valid, err = keymap_binder.validate_keymap_definition(def)

      assert.is_false(valid)
      assert(err)
      assert(err:find("key"))
    end)

    it("should return false when action is missing", function()
      local def = {
        key = "d",
      }

      local valid, err = keymap_binder.validate_keymap_definition(def)

      assert.is_false(valid)
      assert(err)
      assert(err:find("action"))
    end)

    it("should return false for empty key", function()
      local def = {
        key = "",
        action = "describe",
      }

      local valid, err = keymap_binder.validate_keymap_definition(def)

      assert.is_false(valid)
      assert(err)
    end)
  end)

  describe("create_handler_wrapper", function()
    it("should create wrapper that calls handler with context", function()
      local called = false
      local received_ctx = nil

      local handler = function(ctx)
        called = true
        received_ctx = ctx
      end

      local context = { resource = { name = "nginx" } }
      local wrapper = keymap_binder.create_handler_wrapper(handler, context)

      wrapper()

      assert.is_true(called)
      assert(received_ctx)
      assert.equals("nginx", received_ctx.resource.name)
    end)

    it("should pass additional args to handler", function()
      local received_args = nil

      local handler = function(_ctx, extra)
        received_args = extra
      end

      local wrapper = keymap_binder.create_handler_wrapper(handler, {})

      wrapper("extra_data")

      assert.equals("extra_data", received_args)
    end)
  end)

  describe("normalize_key", function()
    it("should keep simple keys as-is", function()
      assert.equals("d", keymap_binder.normalize_key("d"))
      assert.equals("l", keymap_binder.normalize_key("l"))
      assert.equals("q", keymap_binder.normalize_key("q"))
    end)

    it("should normalize special keys", function()
      assert.equals("<CR>", keymap_binder.normalize_key("<cr>"))
      assert.equals("<Esc>", keymap_binder.normalize_key("<esc>"))
      assert.equals("<Tab>", keymap_binder.normalize_key("<tab>"))
    end)

    it("should handle ctrl combinations", function()
      assert.equals("<C-c>", keymap_binder.normalize_key("<c-c>"))
      assert.equals("<C-d>", keymap_binder.normalize_key("<c-d>"))
    end)
  end)

  describe("create_keymaps_from_definitions", function()
    it("should create keymap configs from definitions list", function()
      local defs = {
        { key = "d", action = "describe", desc = "Describe" },
        { key = "l", action = "logs", desc = "View logs" },
        { key = "q", action = "quit", desc = "Quit" },
      }

      local configs = keymap_binder.create_keymaps_from_definitions(defs)

      assert.equals(3, #configs)
      assert.equals("d", configs[1].key)
      assert.equals("l", configs[2].key)
      assert.equals("q", configs[3].key)
    end)

    it("should skip invalid definitions", function()
      local defs = {
        { key = "d", action = "describe" },
        { key = "", action = "invalid" }, -- invalid
        { action = "no_key" }, -- invalid
        { key = "q", action = "quit" },
      }

      local configs = keymap_binder.create_keymaps_from_definitions(defs)

      assert.equals(2, #configs)
    end)
  end)

  describe("get_action_for_key", function()
    it("should return action for mapped key", function()
      local keymaps = {
        { key = "d", action = "describe" },
        { key = "l", action = "logs" },
      }

      local action = keymap_binder.get_action_for_key(keymaps, "d")

      assert.equals("describe", action)
    end)

    it("should return nil for unmapped key", function()
      local keymaps = {
        { key = "d", action = "describe" },
      }

      local action = keymap_binder.get_action_for_key(keymaps, "x")

      assert.is_nil(action)
    end)

    it("should handle normalized keys", function()
      local keymaps = {
        { key = "<CR>", action = "select" },
      }

      local action = keymap_binder.get_action_for_key(keymaps, "<cr>")

      assert.equals("select", action)
    end)
  end)

  describe("create_binding_state", function()
    it("should create initial binding state", function()
      local state = keymap_binder.create_binding_state()

      assert.is_table(state.bindings)
      assert.equals(0, #state.bindings)
      assert.is_nil(state.bufnr)
    end)
  end)
end)
