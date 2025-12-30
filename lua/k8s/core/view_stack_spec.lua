--- view_stack_spec.lua - ビュースタック管理のテスト

local view_stack = require("k8s.core.view_stack")

describe("view_stack", function()
  describe("create", function()
    it("should create empty stack", function()
      local stack = view_stack.create()

      assert.is_table(stack)
      assert.equals(0, view_stack.size(stack))
    end)
  end)

  describe("push", function()
    it("should add view to stack", function()
      local stack = view_stack.create()

      local new_stack = view_stack.push(stack, { type = "list", kind = "Pod" })

      assert.equals(1, view_stack.size(new_stack))
    end)

    it("should preserve previous views", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list", kind = "Pod" })
      stack = view_stack.push(stack, { type = "describe", name = "nginx" })

      assert.equals(2, view_stack.size(stack))
    end)

    it("should not modify original stack", function()
      local stack = view_stack.create()
      view_stack.push(stack, { type = "list" })

      assert.equals(0, view_stack.size(stack))
    end)
  end)

  describe("pop", function()
    it("should remove top view", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list" })
      stack = view_stack.push(stack, { type = "describe" })

      local new_stack, popped = view_stack.pop(stack)

      assert.equals(1, view_stack.size(new_stack))
      assert.equals("describe", popped.type)
    end)

    it("should return nil when stack is empty", function()
      local stack = view_stack.create()

      local new_stack, popped = view_stack.pop(stack)

      assert.equals(0, view_stack.size(new_stack))
      assert.is_nil(popped)
    end)
  end)

  describe("current", function()
    it("should return top view", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list" })
      stack = view_stack.push(stack, { type = "describe" })

      local current_view = view_stack.current(stack)

      assert.equals("describe", current_view.type)
    end)

    it("should return nil for empty stack", function()
      local stack = view_stack.create()

      assert.is_nil(view_stack.current(stack))
    end)
  end)

  describe("clear", function()
    it("should remove all views", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list" })
      stack = view_stack.push(stack, { type = "describe" })

      local cleared = view_stack.clear(stack)

      assert.equals(0, view_stack.size(cleared))
    end)
  end)

  describe("can_pop", function()
    it("should return true when stack has multiple items", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list" })
      stack = view_stack.push(stack, { type = "describe" })

      assert.is_true(view_stack.can_pop(stack))
    end)

    it("should return false when stack has one item", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list" })

      assert.is_false(view_stack.can_pop(stack))
    end)

    it("should return false when stack is empty", function()
      local stack = view_stack.create()

      assert.is_false(view_stack.can_pop(stack))
    end)
  end)

  describe("peek", function()
    it("should return view at index without removing", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list" })
      stack = view_stack.push(stack, { type = "describe" })

      local view = view_stack.peek(stack, 1)

      assert.equals("list", view.type)
      assert.equals(2, view_stack.size(stack))
    end)

    it("should return nil for invalid index", function()
      local stack = view_stack.create()
      stack = view_stack.push(stack, { type = "list" })

      assert.is_nil(view_stack.peek(stack, 5))
    end)
  end)
end)
