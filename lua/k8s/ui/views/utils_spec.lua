--- utils_spec.lua - View共通ユーティリティのテスト

local utils = require("k8s.ui.views.utils")

describe("utils", function()
  describe("calculate_cursor_position", function()
    it("should return 1 for first item", function()
      local pos = utils.calculate_cursor_position(1, 10)
      assert.equals(1, pos)
    end)

    it("should preserve position when within bounds", function()
      local pos = utils.calculate_cursor_position(5, 10)
      assert.equals(5, pos)
    end)

    it("should clamp to last item when position exceeds count", function()
      local pos = utils.calculate_cursor_position(15, 10)
      assert.equals(10, pos)
    end)

    it("should return 1 when position is 0", function()
      local pos = utils.calculate_cursor_position(0, 10)
      assert.equals(1, pos)
    end)

    it("should return 1 when count is 0", function()
      local pos = utils.calculate_cursor_position(5, 0)
      assert.equals(1, pos)
    end)
  end)

  describe("get_item_at_cursor", function()
    local items = {
      { name = "first" },
      { name = "second" },
      { name = "third" },
    }

    it("should return item at cursor position", function()
      local item = utils.get_item_at_cursor(items, 2)
      assert(item)
      assert.equals("second", item.name)
    end)

    it("should return nil for invalid position", function()
      local item = utils.get_item_at_cursor(items, 0)
      assert.is_nil(item)
    end)

    it("should return nil for position exceeding count", function()
      local item = utils.get_item_at_cursor(items, 10)
      assert.is_nil(item)
    end)

    it("should return nil for empty list", function()
      local item = utils.get_item_at_cursor({}, 1)
      assert.is_nil(item)
    end)
  end)
end)
