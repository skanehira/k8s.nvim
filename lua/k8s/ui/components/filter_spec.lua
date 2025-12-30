--- filter_spec.lua - フィルター入力コンポーネントのテスト

local filter = require("k8s.ui.components.filter")

describe("filter", function()
  describe("create_prompt", function()
    it("should create filter prompt with prefix", function()
      local prompt = filter.create_prompt()
      assert.equals("/", prompt)
    end)
  end)

  describe("parse_input", function()
    it("should return input as is when valid", function()
      local result = filter.parse_input("nginx")
      assert.equals("nginx", result)
    end)

    it("should trim whitespace", function()
      local result = filter.parse_input("  nginx  ")
      assert.equals("nginx", result)
    end)

    it("should return empty string for nil input", function()
      local result = filter.parse_input(nil)
      assert.equals("", result)
    end)

    it("should return empty string for empty input", function()
      local result = filter.parse_input("")
      assert.equals("", result)
    end)
  end)

  describe("should_clear_filter", function()
    it("should return true for empty string", function()
      assert.is_true(filter.should_clear_filter(""))
    end)

    it("should return false for non-empty string", function()
      assert.is_false(filter.should_clear_filter("nginx"))
    end)
  end)

  describe("format_display", function()
    it("should format filter text for header display", function()
      local display = filter.format_display("nginx")
      assert.equals("Filter: nginx", display)
    end)

    it("should return empty string when no filter", function()
      local display = filter.format_display("")
      assert.equals("", display)
    end)

    it("should return empty string for nil", function()
      local display = filter.format_display(nil)
      assert.equals("", display)
    end)
  end)
end)
