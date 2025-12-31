--- view_helper_spec.lua - ビューヘルパーのテスト

local view_helper = require("k8s.handlers.view_helper")

describe("view_helper", function()
  describe("create_view_config", function()
    it("should create config with required fields", function()
      local config = view_helper.create_view_config({
        view_type = "detail",
        header = {
          context = "test-context",
          namespace = "default",
          view = "Test View",
        },
        footer_view_type = "describe",
        view_stack_entry = { type = "describe" },
      })

      assert.equals("detail", config.view_type)
      assert.equals("test-context", config.header.context)
      assert.equals("default", config.header.namespace)
      assert.equals("Test View", config.header.view)
      assert.equals("describe", config.footer_view_type)
      assert.equals("describe", config.view_stack_entry.type)
    end)

    it("should set default values for optional fields", function()
      local config = view_helper.create_view_config({
        view_type = "list",
        header = {
          context = "ctx",
          namespace = "ns",
          view = "view",
        },
        footer_view_type = "list",
        view_stack_entry = { type = "list" },
      })

      assert.is_false(config.transparent)
      assert.is_nil(config.footer_kind)
      assert.is_nil(config.initial_content)
      assert.is_nil(config.on_mounted)
      assert.is_false(config.pre_render)
    end)

    it("should accept optional fields", function()
      local on_mounted_fn = function() end
      local config = view_helper.create_view_config({
        view_type = "detail",
        transparent = true,
        header = {
          context = "ctx",
          namespace = "ns",
          view = "view",
          loading = true,
        },
        footer_view_type = "describe",
        footer_kind = "Pod",
        view_stack_entry = { type = "describe" },
        initial_content = { "Loading..." },
        on_mounted = on_mounted_fn,
        pre_render = true,
      })

      assert.is_true(config.transparent)
      assert.equals("Pod", config.footer_kind)
      assert.is_true(config.header.loading)
      assert.same({ "Loading..." }, config.initial_content)
      assert.equals(on_mounted_fn, config.on_mounted)
      assert.is_true(config.pre_render)
    end)
  end)

  describe("validate_config", function()
    it("should return true for valid config", function()
      local config = {
        view_type = "detail",
        header = {
          context = "ctx",
          namespace = "ns",
          view = "view",
        },
        footer_view_type = "describe",
        view_stack_entry = { type = "describe" },
      }

      local valid, err = view_helper.validate_config(config)

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false for missing view_type", function()
      local config = {
        header = { context = "ctx", namespace = "ns", view = "v" },
        footer_view_type = "describe",
        view_stack_entry = { type = "describe" },
      }

      local valid, err = view_helper.validate_config(config)

      assert.is_false(valid)
      assert.equals("view_type is required", err)
    end)

    it("should return false for invalid view_type", function()
      local config = {
        view_type = "invalid",
        header = { context = "ctx", namespace = "ns", view = "v" },
        footer_view_type = "describe",
        view_stack_entry = { type = "describe" },
      }

      local valid, err = view_helper.validate_config(config)

      assert.is_false(valid)
      assert.equals("view_type must be 'list' or 'detail'", err)
    end)

    it("should return false for missing header", function()
      local config = {
        view_type = "detail",
        footer_view_type = "describe",
        view_stack_entry = { type = "describe" },
      }

      local valid, err = view_helper.validate_config(config)

      assert.is_false(valid)
      assert.equals("header is required", err)
    end)

    it("should return false for missing footer_view_type", function()
      local config = {
        view_type = "detail",
        header = { context = "ctx", namespace = "ns", view = "v" },
        view_stack_entry = { type = "describe" },
      }

      local valid, err = view_helper.validate_config(config)

      assert.is_false(valid)
      assert.equals("footer_view_type is required", err)
    end)

    it("should return false for missing view_stack_entry", function()
      local config = {
        view_type = "detail",
        header = { context = "ctx", namespace = "ns", view = "v" },
        footer_view_type = "describe",
      }

      local valid, err = view_helper.validate_config(config)

      assert.is_false(valid)
      assert.equals("view_stack_entry is required", err)
    end)
  end)

  describe("get_current_cursor", function()
    it("should return 1 when window is nil", function()
      local cursor = view_helper.get_current_cursor(nil, {
        get_cursor = function()
          return 5
        end,
      })

      assert.equals(1, cursor)
    end)

    it("should return cursor from window module", function()
      local mock_win = { id = 123 }
      local cursor = view_helper.get_current_cursor(mock_win, {
        get_cursor = function(win)
          if win == mock_win then
            return 10
          end
          return 1
        end,
      })

      assert.equals(10, cursor)
    end)
  end)

  describe("prepare_header_content", function()
    it("should create header content using buffer module", function()
      local mock_buffer = {
        create_header_content = function(opts)
          return "Context: " .. opts.context .. " | NS: " .. opts.namespace
        end,
      }

      local content = view_helper.prepare_header_content({
        context = "my-ctx",
        namespace = "my-ns",
        view = "Pods",
      }, mock_buffer)

      assert.equals("Context: my-ctx | NS: my-ns", content)
    end)
  end)

  describe("prepare_footer_content", function()
    it("should create footer content using buffer and callbacks", function()
      local mock_buffer = {
        create_footer_content = function(keymaps)
          return "Keys: " .. #keymaps
        end,
      }
      local mock_callbacks = {
        get_footer_keymaps = function(_view_type, _kind)
          return { { key = "q", action = "quit" }, { key = "r", action = "refresh" } }
        end,
      }

      local content = view_helper.prepare_footer_content("list", "Pod", mock_buffer, mock_callbacks)

      assert.equals("Keys: 2", content)
    end)
  end)
end)
