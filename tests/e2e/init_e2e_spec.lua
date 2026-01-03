--- init_e2e_spec.lua - E2E tests for k8s.nvim main flow

describe("k8s.nvim E2E", function()
  local k8s
  local state
  local watch_adapter

  -- Mock buffers for window sections
  local mock_buffer_lines = {}
  local mock_buffer_id = 100

  -- Mock watch events
  local mock_events = {}

  -- Create mock window that simulates nui.popup behavior
  local function create_mock_window()
    mock_buffer_id = mock_buffer_id + 1
    local header_bufnr = mock_buffer_id
    mock_buffer_id = mock_buffer_id + 1
    local table_header_bufnr = mock_buffer_id
    mock_buffer_id = mock_buffer_id + 1
    local content_bufnr = mock_buffer_id
    mock_buffer_id = mock_buffer_id + 1
    local footer_bufnr = mock_buffer_id

    -- Create actual buffers
    for _, bufnr in ipairs({ header_bufnr, table_header_bufnr, content_bufnr, footer_bufnr }) do
      vim.api.nvim_create_buf(false, true)
      mock_buffer_lines[bufnr] = {}
    end

    return {
      header = { bufnr = header_bufnr, winid = 1000, mount = function() end, unmount = function() end, hide = function() end, show = function() end },
      table_header = { bufnr = table_header_bufnr, winid = 1001, mount = function() end, unmount = function() end, hide = function() end, show = function() end },
      content = { bufnr = content_bufnr, winid = 1002, mount = function() end, unmount = function() end, hide = function() end, show = function() end },
      footer = { bufnr = footer_bufnr, winid = 1003, mount = function() end, unmount = function() end, hide = function() end, show = function() end },
      mounted = false,
      size = { width = 100, height = 40 },
      view_type = "list",
    }
  end

  before_each(function()
    -- Clear all cached modules
    package.loaded["k8s"] = nil
    package.loaded["k8s.init"] = nil
    package.loaded["k8s.state"] = nil
    package.loaded["k8s.state.init"] = nil
    package.loaded["k8s.state.global"] = nil
    package.loaded["k8s.state.view"] = nil
    package.loaded["k8s.handlers.watcher"] = nil
    package.loaded["k8s.adapters.kubectl.watch"] = nil
    package.loaded["k8s.ui.nui.window"] = nil
    package.loaded["k8s.views.list"] = nil
    package.loaded["k8s.views.keymaps"] = nil

    -- Reset mock state
    mock_buffer_lines = {}
    mock_buffer_id = 100

    -- Create mock window module BEFORE loading k8s
    package.loaded["k8s.ui.nui.window"] = {
      create_list_view = function(_)
        return create_mock_window()
      end,
      create_detail_view = function(_)
        return create_mock_window()
      end,
      mount = function(win)
        win.mounted = true
      end,
      unmount = function(win)
        win.mounted = false
      end,
      hide = function(_) end,
      show = function(_) end,
      hide_table_header = function(_) end,
      show_table_header = function(_) end,
      is_mounted = function(win)
        return win and win.mounted == true
      end,
      is_visible = function(win)
        return win and win.mounted == true
      end,
      get_header_bufnr = function(win)
        return win and win.header and win.header.bufnr
      end,
      get_table_header_bufnr = function(win)
        return win and win.table_header and win.table_header.bufnr
      end,
      get_content_bufnr = function(win)
        return win and win.content and win.content.bufnr
      end,
      get_footer_bufnr = function(win)
        return win and win.footer and win.footer.bufnr
      end,
      set_cursor = function(_, _, _) end,
      get_cursor = function(_)
        return 1, 0
      end,
      set_lines = function(bufnr, lines)
        mock_buffer_lines[bufnr] = lines
      end,
      add_highlight = function(_, _, _, _, _) end,
      map_key = function(_, _, _, _) end,
    }

    -- Load state module
    state = require("k8s.state")
    state.reset()

    -- Setup watch adapter mock
    watch_adapter = require("k8s.adapters.kubectl.watch")
    watch_adapter._set_job_starter(function(_, opts)
      -- Simulate job started and emit events
      vim.schedule(function()
        if opts.on_stdout then
          for _, event in ipairs(mock_events) do
            opts.on_stdout(1, { vim.json.encode(event) })
          end
        end
      end)
      return 12345 -- Mock job ID
    end)

    -- Load k8s module (uses mocked window module)
    k8s = require("k8s")
  end)

  after_each(function()
    -- Cleanup
    pcall(function()
      k8s.close()
    end)
    watch_adapter._reset_job_starter()
    mock_events = {}
  end)

  describe("open", function()
    it("should create window and mount it", function()
      -- Setup mock events
      mock_events = {
        {
          type = "ADDED",
          object = {
            kind = "Pod",
            apiVersion = "v1",
            metadata = {
              name = "nginx-abc123",
              namespace = "default",
              creationTimestamp = "2024-12-30T10:00:00Z",
            },
            status = {
              phase = "Running",
              containerStatuses = {
                { ready = true, restartCount = 0 },
              },
            },
            spec = {
              containers = {
                { name = "nginx" },
              },
            },
          },
        },
      }

      k8s.open()

      -- Wait for async operations
      vim.wait(500, function()
        return state.get_current_view() ~= nil
      end)

      -- Verify window is created
      local win = state.get_window()
      assert(win, "Window should be created")
      assert.is_true(win.mounted)

      -- Verify view is pushed
      local current_view = state.get_current_view()
      assert(current_view, "Current view should exist")
      assert.equals("pod_list", current_view.type)
    end)

    it("should receive watch events and update state", function()
      mock_events = {
        {
          type = "ADDED",
          object = {
            kind = "Pod",
            apiVersion = "v1",
            metadata = {
              name = "nginx-pod",
              namespace = "default",
              creationTimestamp = "2024-12-30T10:00:00Z",
            },
            status = {
              phase = "Running",
            },
            spec = {
              containers = { { name = "nginx" } },
            },
          },
        },
      }

      k8s.open()

      -- Wait for events to be processed
      vim.wait(1000, function()
        local view = state.get_current_view()
        return view and #view.resources > 0
      end, 50)

      local current_view = state.get_current_view()
      assert(current_view, "Current view should exist")
      assert.equals(1, #current_view.resources, "Should have 1 resource")
      assert.equals("nginx-pod", current_view.resources[1].name)
      assert.equals("Running", current_view.resources[1].status)
    end)

    it("should handle multiple watch events", function()
      mock_events = {
        {
          type = "ADDED",
          object = {
            kind = "Pod",
            metadata = { name = "pod1", namespace = "default", creationTimestamp = "2024-12-30T10:00:00Z" },
            status = { phase = "Running" },
            spec = { containers = { { name = "c1" } } },
          },
        },
        {
          type = "ADDED",
          object = {
            kind = "Pod",
            metadata = { name = "pod2", namespace = "default", creationTimestamp = "2024-12-30T10:00:00Z" },
            status = { phase = "Pending" },
            spec = { containers = { { name = "c2" } } },
          },
        },
      }

      k8s.open()

      vim.wait(1000, function()
        local view = state.get_current_view()
        return view and #view.resources >= 2
      end, 50)

      local current_view = state.get_current_view()
      assert(current_view, "Current view should exist")
      assert.equals(2, #current_view.resources, "Should have 2 resources")
    end)
  end)

  describe("render", function()
    it("should render footer with keymaps", function()
      mock_events = {
        {
          type = "ADDED",
          object = {
            kind = "Pod",
            metadata = { name = "nginx", namespace = "default", creationTimestamp = "2024-12-30T10:00:00Z" },
            status = { phase = "Running" },
            spec = { containers = { { name = "nginx" } } },
          },
        },
      }

      k8s.open()

      -- Wait for render to complete
      vim.wait(1000, function()
        local win = state.get_window()
        if not win or not win.footer then
          return false
        end
        local lines = mock_buffer_lines[win.footer.bufnr]
        return lines and #lines > 0 and lines[1] ~= ""
      end, 50)

      local win = state.get_window()
      assert(win, "Window should exist")
      local footer_bufnr = win.footer.bufnr
      assert(footer_bufnr, "Footer buffer should exist")

      local lines = mock_buffer_lines[footer_bufnr]
      assert(lines and #lines > 0, "Footer should have lines")
      assert(lines[1]:find("%["), "Footer should contain keymaps: " .. tostring(lines[1]))
    end)

    it("should render content with resources", function()
      mock_events = {
        {
          type = "ADDED",
          object = {
            kind = "Pod",
            metadata = { name = "test-pod", namespace = "default", creationTimestamp = "2024-12-30T10:00:00Z" },
            status = {
              phase = "Running",
              containerStatuses = { { ready = true, restartCount = 0 } },
            },
            spec = { containers = { { name = "test" } } },
          },
        },
      }

      k8s.open()

      -- Wait for render to complete
      vim.wait(1000, function()
        local win = state.get_window()
        if not win or not win.content then
          return false
        end
        local lines = mock_buffer_lines[win.content.bufnr]
        return lines and #lines > 0 and lines[1] ~= ""
      end, 50)

      local win = state.get_window()
      assert(win, "Window should exist")
      local content_bufnr = win.content.bufnr
      assert(content_bufnr, "Content buffer should exist")

      local lines = mock_buffer_lines[content_bufnr]
      assert(lines and #lines > 0, "Content should have lines")
      assert(lines[1]:find("test%-pod"), "Content should contain pod name: " .. tostring(lines[1]))
    end)
  end)

  describe("close", function()
    it("should unmount window and clear state", function()
      mock_events = {}
      k8s.open()

      vim.wait(500, function()
        return state.get_window() ~= nil
      end)

      k8s.close()

      assert.is_nil(state.get_window())
      assert.same({}, state.get_view_stack())
    end)
  end)
end)
