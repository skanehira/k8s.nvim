--- view_restorer_spec.lua - ビュー復帰処理のテスト

local view_restorer = require("k8s.handlers.view_restorer")

describe("view_restorer", function()
  describe("get_restorer", function()
    it("should return restorer for list view", function()
      local restorer = view_restorer.get_restorer("list")

      assert.is_function(restorer)
    end)

    it("should return restorer for describe view", function()
      local restorer = view_restorer.get_restorer("describe")

      assert.is_function(restorer)
    end)

    it("should return restorer for help view", function()
      local restorer = view_restorer.get_restorer("help")

      assert.is_function(restorer)
    end)

    it("should return restorer for port_forward_list view", function()
      local restorer = view_restorer.get_restorer("port_forward_list")

      assert.is_function(restorer)
    end)

    it("should return nil for unknown view type", function()
      local restorer = view_restorer.get_restorer("unknown")

      assert.is_nil(restorer)
    end)
  end)

  describe("get_footer_params", function()
    it("should return list footer params", function()
      local view = { type = "list", kind = "Pod" }
      local app_state = { current_kind = "Deployment" }

      local view_type, kind = view_restorer.get_footer_params(view, app_state)

      assert.equals("list", view_type)
      assert.equals("Pod", kind)
    end)

    it("should use app_state kind when view kind is nil", function()
      local view = { type = "list" }
      local app_state = { current_kind = "Deployment" }

      local view_type, kind = view_restorer.get_footer_params(view, app_state)

      assert.equals("list", view_type)
      assert.equals("Deployment", kind)
    end)

    it("should return describe footer params", function()
      local view = { type = "describe", resource = { kind = "Pod" } }

      local view_type, kind = view_restorer.get_footer_params(view, nil)

      assert.equals("describe", view_type)
      assert.equals("Pod", kind)
    end)

    it("should return help footer params", function()
      local view = { type = "help" }

      local view_type, kind = view_restorer.get_footer_params(view, nil)

      assert.equals("help", view_type)
      assert.is_nil(kind)
    end)

    it("should return port_forward_list footer params", function()
      local view = { type = "port_forward_list" }

      local view_type, kind = view_restorer.get_footer_params(view, nil)

      assert.equals("port_forward_list", view_type)
      assert.is_nil(kind)
    end)
  end)

  describe("needs_refetch", function()
    it("should return true for list view with different kind", function()
      local view = { type = "list", kind = "Pod" }
      local app_state = { current_kind = "Deployment" }

      local result = view_restorer.needs_refetch(view, app_state)

      assert.is_true(result)
    end)

    it("should return false for list view with same kind", function()
      local view = { type = "list", kind = "Pod" }
      local app_state = { current_kind = "Pod" }

      local result = view_restorer.needs_refetch(view, app_state)

      assert.is_false(result)
    end)

    it("should return false for non-list view", function()
      local view = { type = "describe" }
      local app_state = { current_kind = "Pod" }

      local result = view_restorer.needs_refetch(view, app_state)

      assert.is_false(result)
    end)
  end)
end)
