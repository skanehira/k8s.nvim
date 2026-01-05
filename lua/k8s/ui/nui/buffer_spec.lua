--- buffer_spec.lua - バッファ描画のテスト

local buffer = require("k8s.ui.nui.buffer")

describe("buffer", function()
  describe("create_header_content", function()
    it("should create header content with all fields", function()
      local content = buffer.create_header_content({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        filter = "nginx",
      })

      assert(content:find("minikube"))
      assert(content:find("default"))
      assert(content:find("Pods"))
      assert(content:find("nginx"))
    end)

    it("should handle empty filter", function()
      local content = buffer.create_header_content({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        filter = "",
      })

      assert(content:find("minikube"))
      assert.is_nil(content:find("filter"))
    end)

    it("should show loading indicator", function()
      local content = buffer.create_header_content({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        loading = true,
      })

      assert(content:find("Loading") or content:find("loading"))
    end)
  end)

  describe("create_table_line", function()
    it("should create table line from columns and row", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local widths = { 10, 8 }
      local row = { name = "nginx", status = "Running" }

      local line = buffer.create_table_line(columns, widths, row)

      assert(line:find("nginx"))
      assert(line:find("Running"))
    end)

    it("should pad values to column width", function()
      local columns = {
        { key = "name", header = "NAME" },
      }
      local widths = { 10 }
      local row = { name = "app" }

      local line = buffer.create_table_line(columns, widths, row)

      -- "app" padded to 10 chars
      assert.equals(10, #line)
    end)

    it("should handle missing values", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "missing", header = "MISSING" },
      }
      local widths = { 5, 7 }
      local row = { name = "app" }

      local line = buffer.create_table_line(columns, widths, row)

      assert(line:find("app"))
    end)
  end)

  describe("create_header_line", function()
    it("should create header line from columns", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local widths = { 10, 8 }

      local line = buffer.create_header_line(columns, widths)

      assert(line:find("NAME"))
      assert(line:find("STATUS"))
    end)
  end)

  describe("get_highlight_range", function()
    it("should calculate highlight range for column", function()
      local widths = { 10, 8, 10 }
      local col_index = 2

      local range = buffer.get_highlight_range(widths, col_index)

      assert.equals(11, range.start_col) -- after first column + space
      assert.equals(19, range.end_col) -- 11 + 8
    end)

    it("should calculate range for first column", function()
      local widths = { 10, 8 }
      local col_index = 1

      local range = buffer.get_highlight_range(widths, col_index)

      assert.equals(0, range.start_col)
      assert.equals(10, range.end_col)
    end)

    it("should calculate range for last column", function()
      local widths = { 5, 8, 10 }
      local col_index = 3

      local range = buffer.get_highlight_range(widths, col_index)

      assert.equals(15, range.start_col) -- 5 + 1 + 8 + 1
      assert.equals(25, range.end_col) -- 15 + 10
    end)
  end)

  describe("find_status_column_index", function()
    it("should find status column index", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
        { key = "age", header = "AGE" },
      }

      local index = buffer.find_status_column_index(columns, "status")

      assert.equals(2, index)
    end)

    it("should return nil when column not found", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "age", header = "AGE" },
      }

      local index = buffer.find_status_column_index(columns, "status")

      assert.is_nil(index)
    end)
  end)

  describe("prepare_table_content", function()
    it("should prepare table content with header and rows", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local rows = {
        { name = "pod1", status = "Running" },
        { name = "pod2", status = "Pending" },
      }

      local content = buffer.prepare_table_content(columns, rows)

      assert.is_table(content.widths)
      assert(content.header_line:find("NAME"))
      assert.equals(2, #content.data_lines) -- 2 data rows
      assert(content.data_lines[1]:find("pod1"))
    end)

    it("should handle empty rows", function()
      local columns = {
        { key = "name", header = "NAME" },
      }
      local rows = {}

      local content = buffer.prepare_table_content(columns, rows)

      assert(content.header_line:find("NAME"))
      assert.equals(0, #content.data_lines) -- no data rows
    end)
  end)

  describe("create_buffer_state", function()
    it("should create initial buffer state", function()
      local state = buffer.create_buffer_state()

      assert.is_nil(state.bufnr)
      assert.is_table(state.lines)
      assert.equals(0, #state.lines)
    end)
  end)
end)
