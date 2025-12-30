--- menu_actions_spec.lua - メニューアクションのテスト

local menu_actions = require("k8s.handlers.menu_actions")

describe("menu_actions", function()
  describe("create_resource_menu_action", function()
    it("should create resource menu action", function()
      local action = menu_actions.create_resource_menu_action()

      assert.equals("resource_menu", action.type)
    end)
  end)

  describe("create_context_menu_action", function()
    it("should create context menu action", function()
      local action = menu_actions.create_context_menu_action()

      assert.equals("context_menu", action.type)
    end)
  end)

  describe("create_namespace_menu_action", function()
    it("should create namespace menu action", function()
      local action = menu_actions.create_namespace_menu_action()

      assert.equals("namespace_menu", action.type)
    end)
  end)

  describe("get_resource_menu_items", function()
    it("should return list of resource types", function()
      local items = menu_actions.get_resource_menu_items()

      assert(#items > 0)
      -- Should include common resources
      local has_pods = false
      local has_deployments = false
      for _, item in ipairs(items) do
        if item.value == "Pod" then
          has_pods = true
        end
        if item.value == "Deployment" then
          has_deployments = true
        end
      end
      assert.is_true(has_pods)
      assert.is_true(has_deployments)
    end)
  end)

  describe("create_menu_item", function()
    it("should create menu item", function()
      local item = menu_actions.create_menu_item("Pods", "Pod")

      assert.equals("Pods", item.text)
      assert.equals("Pod", item.value)
    end)
  end)

  describe("get_menu_title", function()
    it("should return title for resource menu", function()
      local title = menu_actions.get_menu_title("resource")
      assert(title:find("Resource") or title:find("resource"))
    end)

    it("should return title for context menu", function()
      local title = menu_actions.get_menu_title("context")
      assert(title:find("Context") or title:find("context"))
    end)

    it("should return title for namespace menu", function()
      local title = menu_actions.get_menu_title("namespace")
      assert(title:find("Namespace") or title:find("namespace"))
    end)
  end)

  describe("create_switch_context_action", function()
    it("should create switch context action", function()
      local action = menu_actions.create_switch_context_action("minikube")

      assert.equals("switch_context", action.type)
      assert.equals("minikube", action.context)
    end)
  end)

  describe("create_switch_namespace_action", function()
    it("should create switch namespace action", function()
      local action = menu_actions.create_switch_namespace_action("kube-system")

      assert.equals("switch_namespace", action.type)
      assert.equals("kube-system", action.namespace)
    end)
  end)

  describe("create_switch_resource_action", function()
    it("should create switch resource action", function()
      local action = menu_actions.create_switch_resource_action("Deployment")

      assert.equals("switch_resource", action.type)
      assert.equals("Deployment", action.kind)
    end)
  end)
end)
