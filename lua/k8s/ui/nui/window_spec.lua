--- window_spec.lua - NuiPopupウィンドウ管理のテスト

local window = require("k8s.ui.nui.window")

describe("window", function()
  describe("create_popup_config", function()
    it("should create config for header section", function()
      local config = window.create_popup_config("header", {
        width = 100,
        height = 30,
      })

      assert.equals(100, config.size.width)
      assert.equals(1, config.size.height)
      assert.equals(1, config.position.row)
      assert.equals(0, config.position.col)
      assert.is.Not.Nil(config.border)
      assert.is.Not.Nil(config.border.style)
    end)

    it("should create config for content section", function()
      local config = window.create_popup_config("content", {
        width = 100,
        height = 30,
      })

      assert.equals(100, config.size.width)
      -- 30 - 1 (header) - 1 (table_header) - 1 (footer) - 4 (border rows) = 23
      assert.equals(23, config.size.height)
      assert.equals(3, config.position.row)
    end)

    it("should create config for footer section", function()
      local config = window.create_popup_config("footer", {
        width = 100,
        height = 30,
      })

      assert.equals(100, config.size.width)
      assert.equals(1, config.size.height)
      assert.equals(30, config.position.row)
    end)
  end)

  describe("create_window_state", function()
    it("should create initial window state", function()
      local state = window.create_window_state()

      assert.is_false(state.mounted)
      assert.is_nil(state.header)
      assert.is_nil(state.table_header)
      assert.is_nil(state.content)
      assert.is_nil(state.footer)
    end)
  end)

  describe("get_center_position", function()
    it("should calculate center position for popup", function()
      local pos = window.get_center_position(80, 24, 60, 20)

      assert.equals(10, pos.col) -- (80 - 60) / 2
      assert.equals(2, pos.row) -- (24 - 20) / 2
    end)

    it("should handle small screen", function()
      local pos = window.get_center_position(40, 10, 60, 20)

      -- Should not go negative
      assert.equals(0, pos.col)
      assert.equals(0, pos.row)
    end)
  end)

  describe("calculate_popup_size", function()
    it("should calculate 80% of screen by default", function()
      local size = window.calculate_popup_size(100, 50)

      assert.equals(80, size.width)
      assert.equals(40, size.height)
    end)

    it("should respect custom percentage", function()
      local size = window.calculate_popup_size(100, 50, { width_pct = 0.5, height_pct = 0.6 })

      assert.equals(50, size.width)
      assert.equals(30, size.height)
    end)

    it("should enforce minimum size", function()
      local size = window.calculate_popup_size(20, 10)

      -- Minimum width is 40, minimum height is 10
      assert.equals(40, size.width)
      assert.equals(10, size.height)
    end)
  end)

  describe("get_buffer_options", function()
    it("should return default buffer options", function()
      local opts = window.get_buffer_options()

      assert.equals("nofile", opts.buftype)
      assert.is_false(opts.swapfile)
      assert.is_false(opts.modifiable)
    end)

    it("should allow modifiable override", function()
      local opts = window.get_buffer_options({ modifiable = true })

      assert.is_true(opts.modifiable)
    end)
  end)

  describe("get_window_options", function()
    it("should return default window options", function()
      local opts = window.get_window_options()

      assert.is_false(opts.wrap)
      assert.is_false(opts.number)
      assert.is_false(opts.relativenumber)
      -- cursorline is only true for "content" section
      assert.is_false(opts.cursorline)
    end)

    it("should return content specific options with cursorline", function()
      local opts = window.get_window_options("content")

      assert.is_true(opts.cursorline)
    end)

    it("should return header specific options", function()
      local opts = window.get_window_options("header")

      assert.is_false(opts.cursorline)
    end)

    it("should return footer specific options", function()
      local opts = window.get_window_options("footer")

      assert.is_false(opts.cursorline)
    end)
  end)

  describe("validate_section", function()
    it("should return true for valid sections", function()
      assert.is_true(window.validate_section("header"))
      assert.is_true(window.validate_section("table_header"))
      assert.is_true(window.validate_section("content"))
      assert.is_true(window.validate_section("footer"))
    end)

    it("should return false for invalid sections", function()
      assert.is_false(window.validate_section("invalid"))
      assert.is_false(window.validate_section(""))
      assert.is_false(window.validate_section(nil))
    end)
  end)
end)
