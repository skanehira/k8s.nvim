local layout = require("k8s.ui.components.layout")

describe("layout", function()
  describe("calculate_dimensions", function()
    it("should calculate dimensions for full screen layout", function()
      local dims = layout.calculate_dimensions(100, 40)

      -- 全体サイズ
      assert.equals(100, dims.width)
      assert.equals(40, dims.total_height)

      -- ヘッダー（1行）
      assert.equals(1, dims.header.height)
      assert.equals(1, dims.header.row)

      -- フッター（1行）
      assert.equals(1, dims.footer.height)
      assert.equals(40, dims.footer.row)

      -- コンテンツ（残り）
      assert.equals(38, dims.content.height) -- 40 - 1(header) - 1(footer)
      assert.equals(2, dims.content.row)
    end)

    it("should handle small screen", function()
      local dims = layout.calculate_dimensions(80, 20)

      assert.equals(80, dims.width)
      assert.equals(20, dims.total_height)
      assert.equals(18, dims.content.height) -- 20 - 1 - 1
    end)

    it("should handle minimum height", function()
      local dims = layout.calculate_dimensions(80, 5)

      assert.equals(5, dims.total_height)
      assert.equals(3, dims.content.height) -- 5 - 1 - 1
    end)
  end)

  describe("create_popup_options", function()
    it("should create header popup options", function()
      local dims = layout.calculate_dimensions(100, 40)
      local opts = layout.create_popup_options("header", dims)

      assert.equals("none", opts.border)
      assert.equals(100, opts.size.width)
      assert.equals(1, opts.size.height)
      assert.equals(1, opts.position.row)
      assert.equals(0, opts.position.col)
    end)

    it("should create content popup options", function()
      local dims = layout.calculate_dimensions(100, 40)
      local opts = layout.create_popup_options("content", dims)

      assert.equals("none", opts.border)
      assert.equals(100, opts.size.width)
      assert.equals(38, opts.size.height)
      assert.equals(2, opts.position.row)
    end)

    it("should create footer popup options", function()
      local dims = layout.calculate_dimensions(100, 40)
      local opts = layout.create_popup_options("footer", dims)

      assert.equals("none", opts.border)
      assert.equals(100, opts.size.width)
      assert.equals(1, opts.size.height)
      assert.equals(40, opts.position.row)
    end)
  end)
end)
