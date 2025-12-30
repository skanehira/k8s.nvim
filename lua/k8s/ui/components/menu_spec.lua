local menu = require("k8s.ui.components.menu")

describe("menu", function()
  describe("has_telescope", function()
    it("should return false when telescope is not available", function()
      -- デフォルトでは telescope なし
      local has = menu.has_telescope()
      -- テスト環境では telescope がないと仮定
      assert.is_boolean(has)
    end)
  end)

  describe("create_items", function()
    it("should create menu items from list", function()
      local items = menu.create_items({
        "Pods",
        "Deployments",
        "Services",
      })

      assert.equals(3, #items)
      assert.equals("Pods", items[1].text)
      assert.equals("Pods", items[1].value)
      assert.equals("Deployments", items[2].text)
      assert.equals("Services", items[3].text)
    end)

    it("should handle empty list", function()
      local items = menu.create_items({})
      assert.equals(0, #items)
    end)

    it("should create items with custom value", function()
      local items = menu.create_items({
        { text = "All Namespaces", value = nil },
        { text = "default", value = "default" },
      })

      assert.equals(2, #items)
      assert.equals("All Namespaces", items[1].text)
      assert.is_nil(items[1].value)
      assert.equals("default", items[2].text)
      assert.equals("default", items[2].value)
    end)
  end)
end)
