--- view_helper_spec.lua - ビューヘルパーのテスト

local view_helper = require("k8s.handlers.view_helper")

describe("view_helper", function()
  describe("create_view", function()
    it("should be a function", function()
      assert.is_function(view_helper.create_view)
    end)
  end)

  describe("_write_buffers_before_mount", function()
    it("should be a function", function()
      assert.is_function(view_helper._write_buffers_before_mount)
    end)
  end)

  describe("_write_buffers_after_mount", function()
    it("should be a function", function()
      assert.is_function(view_helper._write_buffers_after_mount)
    end)
  end)
end)
