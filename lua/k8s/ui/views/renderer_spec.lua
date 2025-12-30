--- renderer_spec.lua - 描画モジュールのテスト

local renderer = require("k8s.ui.views.renderer")

describe("renderer", function()
  describe("create_layout_config", function()
    it("should create layout config with default values", function()
      local config = renderer.create_layout_config()

      assert.equals(1, config.header_height)
      assert.equals(1, config.footer_height)
      assert.is_true(config.border == "none" or config.border == nil)
    end)

    it("should create layout config with custom values", function()
      local config = renderer.create_layout_config({
        header_height = 2,
        footer_height = 3,
      })

      assert.equals(2, config.header_height)
      assert.equals(3, config.footer_height)
    end)
  end)

  describe("calculate_popup_positions", function()
    it("should calculate positions for 3 windows", function()
      local positions = renderer.calculate_popup_positions({
        width = 100,
        height = 30,
        header_height = 1,
        footer_height = 1,
      })

      assert(positions.header)
      assert(positions.content)
      assert(positions.footer)

      -- Header at top
      assert.equals(1, positions.header.row)
      assert.equals(1, positions.header.height)
      assert.equals(100, positions.header.width)

      -- Content in middle
      assert.equals(2, positions.content.row)
      assert.equals(28, positions.content.height) -- 30 - 1 - 1

      -- Footer at bottom
      assert.equals(30, positions.footer.row)
      assert.equals(1, positions.footer.height)
    end)

    it("should handle expanded footer for help view", function()
      local positions = renderer.calculate_popup_positions({
        width = 100,
        height = 30,
        header_height = 1,
        footer_height = 6, -- Expanded for help
      })

      assert.equals(25, positions.content.row + positions.content.height)
      assert.equals(6, positions.footer.height)
    end)
  end)

  describe("build_header_line", function()
    it("should build header line with context and namespace", function()
      local line = renderer.build_header_line({
        context = "minikube",
        namespace = "default",
        view = "Pods",
      })

      assert.is_string(line)
      assert(line:find("minikube"))
      assert(line:find("default"))
      assert(line:find("Pods"))
    end)

    it("should include filter text when present", function()
      local line = renderer.build_header_line({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        filter = "nginx",
      })

      assert(line:find("nginx"))
    end)

    it("should include loading indicator", function()
      local line = renderer.build_header_line({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        loading = true,
      })

      assert(line:find("Loading"))
    end)

    it("should handle All Namespaces", function()
      local line = renderer.build_header_line({
        context = "minikube",
        namespace = "",
        view = "Pods",
      })

      assert(line:find("All") or line:find("all"))
    end)
  end)

  describe("build_footer_line", function()
    it("should build footer with keymap hints", function()
      local keymaps = {
        { key = "<CR>", desc = "Select" },
        { key = "d", desc = "Describe" },
        { key = "l", desc = "Logs" },
      }

      local line = renderer.build_footer_line(keymaps)

      assert.is_string(line)
      assert(line:find("<CR>"))
      assert(line:find("Select"))
      assert(line:find("Describe"))
    end)

    it("should return empty string for empty keymaps", function()
      local line = renderer.build_footer_line({})
      assert.equals("", line)
    end)
  end)

  describe("build_table_lines", function()
    it("should build table with header and data rows", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local rows = {
        { name = "nginx-abc123", status = "Running" },
        { name = "redis-def456", status = "Pending" },
      }

      local lines = renderer.build_table_lines(columns, rows)

      assert.equals(3, #lines) -- header + 2 data rows
      assert(lines[1]:find("NAME"))
      assert(lines[1]:find("STATUS"))
      assert(lines[2]:find("nginx"))
      assert(lines[3]:find("redis"))
    end)

    it("should return only header for empty rows", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }

      local lines = renderer.build_table_lines(columns, {})

      assert.equals(1, #lines)
      assert(lines[1]:find("NAME"))
    end)
  end)

  describe("get_line_highlights", function()
    it("should return highlight for status column", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local row = { name = "nginx", status = "Running" }

      local highlights = renderer.get_line_highlights(columns, row)

      assert(highlights)
      local status_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.col_key == "status" then
          status_hl = hl
          break
        end
      end
      assert(status_hl)
      assert.equals("K8sStatusRunning", status_hl.hl_group)
    end)

    it("should return pending highlight for Pending status", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local row = { name = "mysql", status = "Pending" }

      local highlights = renderer.get_line_highlights(columns, row)

      local status_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.col_key == "status" then
          status_hl = hl
          break
        end
      end
      assert(status_hl)
      assert.equals("K8sStatusPending", status_hl.hl_group)
    end)

    it("should return error highlight for Failed status", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local row = { name = "app", status = "Failed" }

      local highlights = renderer.get_line_highlights(columns, row)

      local status_hl = nil
      for _, hl in ipairs(highlights) do
        if hl.col_key == "status" then
          status_hl = hl
          break
        end
      end
      assert(status_hl)
      assert.equals("K8sStatusError", status_hl.hl_group)
    end)
  end)

  describe("create_render_state", function()
    it("should create initial render state", function()
      local state = renderer.create_render_state()

      assert(state)
      assert.is_nil(state.header_bufnr)
      assert.is_nil(state.content_bufnr)
      assert.is_nil(state.footer_bufnr)
      assert.is_nil(state.timer)
      assert.is_false(state.mounted)
    end)
  end)

  describe("should_reuse_buffer", function()
    it("should return true when buffer is valid", function()
      local state = renderer.create_render_state()
      -- Simulate valid buffer
      state.content_bufnr = 1

      -- Mock vim.api.nvim_buf_is_valid to return true
      local original_is_valid = vim.api.nvim_buf_is_valid
      vim.api.nvim_buf_is_valid = function(bufnr)
        return bufnr == 1
      end

      local result = renderer.should_reuse_buffer(state, "content")

      vim.api.nvim_buf_is_valid = original_is_valid

      assert.is_true(result)
    end)

    it("should return false when buffer is nil", function()
      local state = renderer.create_render_state()

      local result = renderer.should_reuse_buffer(state, "content")

      assert.is_false(result)
    end)
  end)

  describe("create_keymap_handler", function()
    it("should create handler function for action", function()
      local called = false
      local received_resource = nil

      local callbacks = {
        describe = function(resource)
          called = true
          received_resource = resource
        end,
      }

      local handler = renderer.create_keymap_handler("describe", callbacks)

      assert(handler)
      assert.is_function(handler)

      -- Simulate call
      handler({ name = "nginx", namespace = "default" })

      assert.is_true(called)
      assert(received_resource)
      assert.equals("nginx", received_resource.name)
    end)

    it("should return nil when action not in callbacks", function()
      local callbacks = {}

      local handler = renderer.create_keymap_handler("unknown", callbacks)

      assert.is_nil(handler)
    end)
  end)

  describe("format_keymap_hints", function()
    it("should format keymaps for footer display", function()
      local keymaps = {
        ["<CR>"] = "select",
        ["d"] = "describe",
        ["l"] = "logs",
      }

      local hints = renderer.format_keymap_hints(keymaps)

      assert.is_table(hints)
      assert(#hints >= 3)

      -- Check structure
      for _, hint in ipairs(hints) do
        assert.is_string(hint.key)
        assert.is_string(hint.desc)
      end
    end)

    it("should use human-readable action names", function()
      local keymaps = {
        ["<CR>"] = "select",
        ["D"] = "delete",
        ["?"] = "help",
      }

      local hints = renderer.format_keymap_hints(keymaps)

      local found_select = false
      local found_delete = false
      for _, hint in ipairs(hints) do
        if hint.desc == "Select" then
          found_select = true
        end
        if hint.desc == "Delete" then
          found_delete = true
        end
      end

      assert.is_true(found_select)
      assert.is_true(found_delete)
    end)
  end)

  describe("create_timer_config", function()
    it("should create timer config with interval", function()
      local config = renderer.create_timer_config(5000)

      assert.equals(5000, config.interval)
      assert.is_false(config.is_running)
    end)

    it("should use default interval when not provided", function()
      local config = renderer.create_timer_config()

      assert.equals(5000, config.interval) -- default 5 seconds
    end)
  end)
end)
