--- plugin_spec.lua - プラグインコマンド補完のテスト

local plugin = require("k8s.plugin")

describe("plugin", function()
  describe("complete", function()
    it("should return matching subcommands", function()
      local results = plugin.complete("po")

      assert.is_table(results)
      assert(vim.tbl_contains(results, "pods"))
      assert(vim.tbl_contains(results, "portforwards"))
    end)

    it("should return all subcommands for empty input", function()
      local results = plugin.complete("")

      assert.is_table(results)
      assert(#results > 0)
      assert(vim.tbl_contains(results, "open"))
      assert(vim.tbl_contains(results, "close"))
      assert(vim.tbl_contains(results, "pods"))
    end)

    it("should return empty for non-matching input", function()
      local results = plugin.complete("xyz")

      assert.is_table(results)
      assert.equals(0, #results)
    end)
  end)
end)
