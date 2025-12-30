--- api_spec.lua - 統一APIのテスト

local api = require("k8s.api.api")

describe("api", function()
  describe("create_request", function()
    it("should create get_resources request", function()
      local req = api.create_request("get_resources", {
        kind = "Pod",
        namespace = "default",
      })

      assert.equals("get_resources", req.action)
      assert.equals("Pod", req.params.kind)
      assert.equals("default", req.params.namespace)
    end)

    it("should create describe request", function()
      local req = api.create_request("describe", {
        kind = "Pod",
        name = "nginx",
        namespace = "default",
      })

      assert.equals("describe", req.action)
      assert.equals("nginx", req.params.name)
    end)

    it("should create delete request", function()
      local req = api.create_request("delete", {
        kind = "Pod",
        name = "nginx",
        namespace = "default",
      })

      assert.equals("delete", req.action)
    end)
  end)

  describe("validate_request", function()
    it("should return true for valid get_resources request", function()
      local req = api.create_request("get_resources", { kind = "Pod" })

      local valid, err = api.validate_request(req)

      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false when action is missing", function()
      local req = { params = {} }

      local valid, err = api.validate_request(req)

      assert.is_false(valid)
      assert(err)
    end)

    it("should return false for delete without name", function()
      local req = api.create_request("delete", { kind = "Pod" })

      local valid, err = api.validate_request(req)

      assert.is_false(valid)
      assert(err:find("name"))
    end)
  end)

  describe("get_required_params", function()
    it("should return required params for get_resources", function()
      local params = api.get_required_params("get_resources")

      assert(vim.tbl_contains(params, "kind"))
    end)

    it("should return required params for delete", function()
      local params = api.get_required_params("delete")

      assert(vim.tbl_contains(params, "kind"))
      assert(vim.tbl_contains(params, "name"))
    end)

    it("should return required params for scale", function()
      local params = api.get_required_params("scale")

      assert(vim.tbl_contains(params, "kind"))
      assert(vim.tbl_contains(params, "name"))
      assert(vim.tbl_contains(params, "replicas"))
    end)
  end)

  describe("is_destructive_action", function()
    it("should return true for delete", function()
      assert.is_true(api.is_destructive_action("delete"))
    end)

    it("should return true for restart", function()
      assert.is_true(api.is_destructive_action("restart"))
    end)

    it("should return false for describe", function()
      assert.is_false(api.is_destructive_action("describe"))
    end)

    it("should return false for get_resources", function()
      assert.is_false(api.is_destructive_action("get_resources"))
    end)
  end)

  describe("get_supported_actions", function()
    it("should return list of actions", function()
      local actions = api.get_supported_actions()

      assert(#actions > 0)
      assert(vim.tbl_contains(actions, "get_resources"))
      assert(vim.tbl_contains(actions, "describe"))
      assert(vim.tbl_contains(actions, "delete"))
    end)
  end)

  describe("create_response", function()
    it("should create success response", function()
      local resp = api.create_response(true, { data = "test" })

      assert.is_true(resp.ok)
      assert.equals("test", resp.data.data)
      assert.is_nil(resp.error)
    end)

    it("should create error response", function()
      local resp = api.create_response(false, nil, "Something went wrong")

      assert.is_false(resp.ok)
      assert.is_nil(resp.data)
      assert.equals("Something went wrong", resp.error)
    end)
  end)
end)
