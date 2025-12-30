local tbl = require("k8s.ui.components.table")

describe("table", function()
  describe("calculate_column_widths", function()
    it("should calculate widths based on header and data", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local rows = {
        { name = "nginx-abc123", status = "Running" },
        { name = "redis", status = "Pending" },
      }

      local widths = tbl.calculate_column_widths(columns, rows)

      assert.equals(12, widths[1]) -- "nginx-abc123" is longest
      assert.equals(7, widths[2]) -- "Running" and "Pending" are 7 chars
    end)

    it("should use header width if longer than data", function()
      local columns = {
        { key = "name", header = "NAMESPACE" },
      }
      local rows = {
        { name = "foo" },
      }

      local widths = tbl.calculate_column_widths(columns, rows)

      assert.equals(9, widths[1]) -- "NAMESPACE" is 9 chars
    end)

    it("should handle empty rows", function()
      local columns = {
        { key = "name", header = "NAME" },
      }
      local rows = {}

      local widths = tbl.calculate_column_widths(columns, rows)

      assert.equals(4, widths[1]) -- "NAME" is 4 chars
    end)
  end)

  describe("format_row", function()
    it("should format row with padding", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local widths = { 10, 8 }
      local row = { name = "nginx", status = "Running" }

      local formatted = tbl.format_row(columns, widths, row)

      assert.equals("nginx      Running ", formatted)
    end)

    it("should handle nil values", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local widths = { 10, 8 }
      local row = { name = "nginx" } -- status is nil

      local formatted = tbl.format_row(columns, widths, row)

      assert.equals("nginx              ", formatted)
    end)
  end)

  describe("format_header", function()
    it("should format header row", function()
      local columns = {
        { key = "name", header = "NAME" },
        { key = "status", header = "STATUS" },
      }
      local widths = { 10, 8 }

      local formatted = tbl.format_header(columns, widths)

      assert.equals("NAME       STATUS  ", formatted)
    end)
  end)

  describe("get_status_highlight", function()
    it("should return green for Running", function()
      assert.equals("K8sStatusRunning", tbl.get_status_highlight("Running"))
    end)

    it("should return green for Completed", function()
      assert.equals("K8sStatusRunning", tbl.get_status_highlight("Completed"))
    end)

    it("should return yellow for Pending", function()
      assert.equals("K8sStatusPending", tbl.get_status_highlight("Pending"))
    end)

    it("should return red for Error", function()
      assert.equals("K8sStatusError", tbl.get_status_highlight("Error"))
    end)

    it("should return red for CrashLoopBackOff", function()
      assert.equals("K8sStatusError", tbl.get_status_highlight("CrashLoopBackOff"))
    end)

    it("should return nil for unknown status", function()
      assert.is_nil(tbl.get_status_highlight("Unknown"))
    end)
  end)
end)
