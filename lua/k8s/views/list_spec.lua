--- list_spec.lua - リスト表示ビューのテスト

local list = require("k8s.views.list")

---@diagnostic disable: duplicate-set-field

describe("list", function()
  describe("filter_resources", function()
    it("should return all resources when filter is nil", function()
      local resources = {
        { name = "nginx" },
        { name = "redis" },
      }

      local filtered = list.filter_resources(resources, nil)

      assert.equals(2, #filtered)
    end)

    it("should return all resources when filter is empty string", function()
      local resources = {
        { name = "nginx" },
        { name = "redis" },
      }

      local filtered = list.filter_resources(resources, "")

      assert.equals(2, #filtered)
    end)

    it("should filter resources by name", function()
      local resources = {
        { name = "nginx-abc123" },
        { name = "redis-xyz789" },
        { name = "nginx-def456" },
      }

      local filtered = list.filter_resources(resources, "nginx")

      assert.equals(2, #filtered)
      assert.equals("nginx-abc123", filtered[1].name)
      assert.equals("nginx-def456", filtered[2].name)
    end)

    it("should filter case-insensitively", function()
      local resources = {
        { name = "Nginx-abc123" },
        { name = "redis-xyz789" },
      }

      local filtered = list.filter_resources(resources, "NGINX")

      assert.equals(1, #filtered)
      assert.equals("Nginx-abc123", filtered[1].name)
    end)

    it("should return empty table when no matches", function()
      local resources = {
        { name = "nginx" },
        { name = "redis" },
      }

      local filtered = list.filter_resources(resources, "postgres")

      assert.equals(0, #filtered)
    end)
  end)

  describe("calculate_cursor_position", function()
    it("should return 1 when item_count is 0", function()
      assert.equals(1, list.calculate_cursor_position(5, 0))
    end)

    it("should return 1 when current_pos < 1", function()
      assert.equals(1, list.calculate_cursor_position(0, 10))
      assert.equals(1, list.calculate_cursor_position(-5, 10))
    end)

    it("should return item_count when current_pos > item_count", function()
      assert.equals(10, list.calculate_cursor_position(15, 10))
    end)

    it("should return current_pos when within bounds", function()
      assert.equals(5, list.calculate_cursor_position(5, 10))
    end)
  end)

  describe("prepare_content", function()
    it("should prepare content for Pod resources", function()
      local resources = {
        {
          kind = "Pod",
          name = "nginx-abc123",
          namespace = "default",
          status = "Running",
          age = "5d",
          raw = {
            status = {
              containerStatuses = {
                { ready = true, restartCount = 0 },
              },
            },
          },
        },
      }

      local content = list.prepare_content(resources, "Pod")

      assert.equals(1, content.row_count)
      assert.is_table(content.widths)
      assert.is_string(content.header_line)
      assert.is_table(content.data_lines)
      assert(content.header_line:find("NAME"))
      assert(content.data_lines[1]:find("nginx%-abc123"))
    end)

    it("should handle empty resources", function()
      local content = list.prepare_content({}, "Pod")

      assert.equals(0, content.row_count)
      assert.is_table(content.data_lines)
      assert.equals(0, #content.data_lines)
    end)
  end)

  describe("get_status_highlights", function()
    it("should return highlights for status column", function()
      local rows = {
        { name = "pod1", status = "Running" },
        { name = "pod2", status = "Pending" },
        { name = "pod3", status = "Error" },
      }
      local widths = { 10, 10, 10 } -- NAME, NAMESPACE, STATUS...

      local highlights = list.get_status_highlights("Pod", rows, widths)

      -- Should have highlights for Running, Pending, Error
      assert.equals(3, #highlights)
    end)

    it("should return empty table when no status highlights", function()
      local rows = {
        { name = "pod1", status = "Unknown" },
      }
      local widths = { 10, 10, 10 }

      local highlights = list.get_status_highlights("Pod", rows, widths)

      -- Unknown status doesn't have a highlight
      assert.equals(0, #highlights)
    end)
  end)

  describe("get_resource_at_cursor", function()
    it("should return resource at valid cursor position", function()
      local resources = {
        { name = "pod1" },
        { name = "pod2" },
        { name = "pod3" },
      }

      local resource = list.get_resource_at_cursor(resources, 2)

      assert(resource)
      assert.equals("pod2", resource.name)
    end)

    it("should return nil when cursor < 1", function()
      local resources = { { name = "pod1" } }

      assert.is_nil(list.get_resource_at_cursor(resources, 0))
    end)

    it("should return nil when cursor > count", function()
      local resources = { { name = "pod1" } }

      assert.is_nil(list.get_resource_at_cursor(resources, 2))
    end)
  end)

  describe("render", function()
    local window
    local mock_win
    local rendered_lines
    local header_lines
    local cursor_pos

    before_each(function()
      -- Clear and reload window module for mocking
      package.loaded["k8s.ui.nui.window"] = nil
      window = require("k8s.ui.nui.window")

      rendered_lines = {}
      header_lines = {}
      cursor_pos = nil

      -- Mock window functions
      window.get_table_header_bufnr = function(_)
        return 1
      end
      window.get_content_bufnr = function(_)
        return 2
      end
      window.set_lines = function(bufnr, lines)
        if bufnr == 1 then
          header_lines = lines
        else
          rendered_lines = lines
        end
      end
      window.add_highlight = function(_, _, _, _, _)
        -- Mock highlight
      end
      window.set_cursor = function(_, row, _)
        cursor_pos = row
      end

      mock_win = { mounted = true }

      -- Reload list module to pick up mocked window
      package.loaded["k8s.views.list"] = nil
    end)

    it("should render resources to window", function()
      local list_module = require("k8s.views.list")
      local resources = {
        {
          kind = "Pod",
          name = "nginx",
          namespace = "default",
          status = "Running",
          age = "1d",
          raw = { status = { containerStatuses = { { ready = true, restartCount = 0 } } } },
        },
      }

      list_module.render(mock_win, { resources = resources, kind = "Pod" })

      assert.equals(1, #header_lines)
      assert.equals(1, #rendered_lines)
      assert(header_lines[1]:find("NAME"))
      assert(rendered_lines[1]:find("nginx"))
    end)

    it("should set cursor to 1 when resources exist", function()
      local list_module = require("k8s.views.list")
      local resources = {
        { kind = "Pod", name = "nginx", namespace = "default", status = "Running", age = "1d", raw = {} },
      }

      list_module.render(mock_win, { resources = resources, kind = "Pod" })

      assert.equals(1, cursor_pos)
    end)

    it("should restore cursor position when specified", function()
      local list_module = require("k8s.views.list")
      local resources = {
        { kind = "Pod", name = "nginx1", namespace = "default", status = "Running", age = "1d", raw = {} },
        { kind = "Pod", name = "nginx2", namespace = "default", status = "Running", age = "1d", raw = {} },
        { kind = "Pod", name = "nginx3", namespace = "default", status = "Running", age = "1d", raw = {} },
      }

      list_module.render(mock_win, { resources = resources, kind = "Pod", restore_cursor = 2 })

      assert.equals(2, cursor_pos)
    end)

    it("should handle empty resources", function()
      local list_module = require("k8s.views.list")

      list_module.render(mock_win, { resources = {}, kind = "Pod" })

      assert.equals(0, #rendered_lines)
    end)
  end)
end)
