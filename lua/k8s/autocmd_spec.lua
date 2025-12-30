--- autocmd_spec.lua - オートコマンドのテスト

local autocmd = require("k8s.autocmd")

describe("autocmd", function()
  describe("get_autocmd_definitions", function()
    it("should return autocmd definitions", function()
      local defs = autocmd.get_autocmd_definitions()

      assert.is_table(defs)
      assert(#defs > 0)
    end)

    it("should include VimLeavePre", function()
      local defs = autocmd.get_autocmd_definitions()

      local has_vim_leave = false
      for _, def in ipairs(defs) do
        if def.event == "VimLeavePre" then
          has_vim_leave = true
          break
        end
      end

      assert.is_true(has_vim_leave)
    end)
  end)

  describe("get_group_name", function()
    it("should return group name", function()
      local name = autocmd.get_group_name()

      assert.is_string(name)
      assert(name:find("k8s") or name:find("K8s"))
    end)
  end)

  describe("create_cleanup_callback", function()
    it("should create callback function", function()
      local callback = autocmd.create_cleanup_callback()

      assert.is_function(callback)
    end)
  end)

  describe("should_cleanup_on_event", function()
    it("should return true for VimLeavePre", function()
      assert.is_true(autocmd.should_cleanup_on_event("VimLeavePre"))
    end)

    it("should return true for TabClosed", function()
      assert.is_true(autocmd.should_cleanup_on_event("TabClosed"))
    end)

    it("should return false for other events", function()
      assert.is_false(autocmd.should_cleanup_on_event("BufRead"))
    end)
  end)

  describe("format_autocmd_desc", function()
    it("should format description", function()
      local desc = autocmd.format_autocmd_desc("cleanup port forwards")

      assert(desc:find("k8s") or desc:find("K8s"))
      assert(desc:find("cleanup") or desc:find("port"))
    end)
  end)
end)
