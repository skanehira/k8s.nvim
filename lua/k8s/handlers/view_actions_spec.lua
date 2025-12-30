--- view_actions_spec.lua - ビューアクションのテスト

local view_actions = require("k8s.handlers.view_actions")

describe("view_actions", function()
  describe("create_refresh_action", function()
    it("should create refresh action", function()
      local action = view_actions.create_refresh_action()

      assert.equals("refresh", action.type)
    end)
  end)

  describe("create_help_action", function()
    it("should create help action", function()
      local action = view_actions.create_help_action()

      assert.equals("help", action.type)
    end)
  end)

  describe("create_toggle_secret_action", function()
    it("should create toggle secret action", function()
      local action = view_actions.create_toggle_secret_action()

      assert.equals("toggle_secret", action.type)
    end)
  end)

  describe("create_port_forward_list_action", function()
    it("should create port forward list action", function()
      local action = view_actions.create_port_forward_list_action()

      assert.equals("port_forward_list", action.type)
    end)
  end)

  describe("is_help_visible", function()
    it("should return true when help is shown", function()
      local state = { help_visible = true }
      assert.is_true(view_actions.is_help_visible(state))
    end)

    it("should return false when help is hidden", function()
      local state = { help_visible = false }
      assert.is_false(view_actions.is_help_visible(state))
    end)
  end)

  describe("is_secret_masked", function()
    it("should return true when secrets are masked", function()
      local state = { secret_masked = true }
      assert.is_true(view_actions.is_secret_masked(state))
    end)

    it("should return false when secrets are visible", function()
      local state = { secret_masked = false }
      assert.is_false(view_actions.is_secret_masked(state))
    end)

    it("should default to true", function()
      local state = {}
      assert.is_true(view_actions.is_secret_masked(state))
    end)
  end)

  describe("toggle_help_state", function()
    it("should toggle help visibility", function()
      local state = { help_visible = false }
      local new_state = view_actions.toggle_help_state(state)

      assert.is_true(new_state.help_visible)
    end)

    it("should not modify original state", function()
      local state = { help_visible = false }
      view_actions.toggle_help_state(state)

      assert.is_false(state.help_visible)
    end)
  end)

  describe("toggle_secret_state", function()
    it("should toggle secret mask", function()
      local state = { secret_masked = true }
      local new_state = view_actions.toggle_secret_state(state)

      assert.is_false(new_state.secret_masked)
    end)
  end)

  describe("get_view_action_keymaps", function()
    it("should return view action keymaps", function()
      local keymaps = view_actions.get_view_action_keymaps()

      assert(#keymaps > 0)
      -- Should include common view actions
      local has_refresh = false
      local has_help = false
      for _, km in ipairs(keymaps) do
        if km.action == "refresh" then
          has_refresh = true
        end
        if km.action == "help" then
          has_help = true
        end
      end
      assert.is_true(has_refresh)
      assert.is_true(has_help)
    end)
  end)
end)
