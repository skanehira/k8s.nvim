--- port_forward_list_spec.lua - ポートフォワード一覧Viewのテスト

local pf_list = require("k8s.ui.views.port_forward_list")

describe("port_forward_list", function()
  describe("get_default_keymaps", function()
    it("should return keymap definitions", function()
      local keymaps = pf_list.get_default_keymaps()

      assert.is.Not.Nil(keymaps["<C-h>"])
      assert.equals("back", keymaps["<C-h>"])

      assert.is.Not.Nil(keymaps["D"])
      assert.equals("stop", keymaps["D"])

      assert.is.Not.Nil(keymaps["q"])
      assert.equals("quit", keymaps["q"])
    end)
  end)

  describe("get_action_for_key", function()
    it("should return action name for valid key", function()
      local action = pf_list.get_action_for_key("D")
      assert.equals("stop", action)
    end)

    it("should return nil for unmapped key", function()
      local action = pf_list.get_action_for_key("z")
      assert.is_nil(action)
    end)
  end)

  describe("get_columns", function()
    it("should return column definitions", function()
      local columns = pf_list.get_columns()

      assert.equals(4, #columns)
      assert.equals("LOCAL", columns[1].header)
      assert.equals("local_port", columns[1].key)

      assert.equals("REMOTE", columns[2].header)
      assert.equals("remote_port", columns[2].key)

      assert.equals("RESOURCE", columns[3].header)
      assert.equals("resource", columns[3].key)

      assert.equals("STATUS", columns[4].header)
      assert.equals("status", columns[4].key)
    end)
  end)

  describe("format_connection", function()
    it("should format connection for display", function()
      local conn = {
        job_id = 123,
        resource = "pod/nginx-abc123",
        namespace = "default",
        local_port = 8080,
        remote_port = 80,
      }

      local formatted = pf_list.format_connection(conn)

      assert.equals(8080, formatted.local_port)
      assert.equals(80, formatted.remote_port)
      assert.equals("pod/nginx-abc123", formatted.resource)
      assert.equals("Running", formatted.status)
    end)
  end)

  describe("get_connection_at_cursor", function()
    local connections = {
      { job_id = 1, resource = "pod/nginx" },
      { job_id = 2, resource = "pod/redis" },
      { job_id = 3, resource = "svc/frontend" },
    }

    it("should return connection at cursor position", function()
      local conn = pf_list.get_connection_at_cursor(connections, 2)
      assert(conn)
      assert.equals(2, conn.job_id)
      assert.equals("pod/redis", conn.resource)
    end)

    it("should return nil for invalid position", function()
      local conn = pf_list.get_connection_at_cursor(connections, 0)
      assert.is_nil(conn)
    end)

    it("should return nil for position exceeding count", function()
      local conn = pf_list.get_connection_at_cursor(connections, 10)
      assert.is_nil(conn)
    end)

    it("should return nil for empty connections", function()
      local conn = pf_list.get_connection_at_cursor({}, 1)
      assert.is_nil(conn)
    end)
  end)

  describe("calculate_cursor_position", function()
    it("should preserve position when within bounds", function()
      local pos = pf_list.calculate_cursor_position(5, 10)
      assert.equals(5, pos)
    end)

    it("should clamp to last item when position exceeds count", function()
      local pos = pf_list.calculate_cursor_position(15, 10)
      assert.equals(10, pos)
    end)

    it("should return 1 when position is 0", function()
      local pos = pf_list.calculate_cursor_position(0, 10)
      assert.equals(1, pos)
    end)

    it("should return 1 when count is 0", function()
      local pos = pf_list.calculate_cursor_position(5, 0)
      assert.equals(1, pos)
    end)
  end)
end)
