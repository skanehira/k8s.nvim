--- update_loop_spec.lua - 更新ループのテスト

local update_loop = require("k8s.app.update_loop")

describe("update_loop", function()
  describe("create_state", function()
    it("should create initial update loop state", function()
      local state = update_loop.create_state()

      assert.is_false(state.loading)
      assert.is_nil(state.last_update)
      assert.is_nil(state.error)
    end)
  end)

  describe("set_loading", function()
    it("should set loading state", function()
      local state = update_loop.create_state()

      local new_state = update_loop.set_loading(state, true)

      assert.is_true(new_state.loading)
    end)

    it("should not modify original state", function()
      local state = update_loop.create_state()

      update_loop.set_loading(state, true)

      assert.is_false(state.loading)
    end)
  end)

  describe("set_error", function()
    it("should set error state", function()
      local state = update_loop.create_state()

      local new_state = update_loop.set_error(state, "Connection failed")

      assert.equals("Connection failed", new_state.error)
    end)

    it("should clear loading on error", function()
      local state = update_loop.create_state()
      state = update_loop.set_loading(state, true)

      local new_state = update_loop.set_error(state, "Error")

      assert.is_false(new_state.loading)
    end)
  end)

  describe("clear_error", function()
    it("should clear error", function()
      local state = update_loop.create_state()
      state = update_loop.set_error(state, "Error")

      local new_state = update_loop.clear_error(state)

      assert.is_nil(new_state.error)
    end)
  end)

  describe("set_last_update", function()
    it("should set last update time", function()
      local state = update_loop.create_state()
      local now = os.time()

      local new_state = update_loop.set_last_update(state, now)

      assert.equals(now, new_state.last_update)
    end)

    it("should clear loading on update", function()
      local state = update_loop.create_state()
      state = update_loop.set_loading(state, true)

      local new_state = update_loop.set_last_update(state, os.time())

      assert.is_false(new_state.loading)
    end)
  end)

  describe("should_update", function()
    it("should return true when last_update is nil", function()
      local state = update_loop.create_state()

      assert.is_true(update_loop.should_update(state, 5000))
    end)

    it("should return true when interval has passed", function()
      local state = update_loop.create_state()
      state = update_loop.set_last_update(state, os.time() - 10)

      assert.is_true(update_loop.should_update(state, 5000))
    end)

    it("should return false when loading", function()
      local state = update_loop.create_state()
      state = update_loop.set_loading(state, true)

      assert.is_false(update_loop.should_update(state, 5000))
    end)
  end)

  describe("format_error_message", function()
    it("should format error message", function()
      local msg = update_loop.format_error_message("kubectl not found")

      assert(msg:find("kubectl not found"))
    end)
  end)

  describe("get_retry_delay", function()
    it("should return retry delay", function()
      local delay = update_loop.get_retry_delay(1)

      assert(delay > 0)
    end)

    it("should increase delay with attempt count", function()
      local delay1 = update_loop.get_retry_delay(1)
      local delay2 = update_loop.get_retry_delay(2)

      assert(delay2 >= delay1)
    end)

    it("should cap at max delay", function()
      local delay = update_loop.get_retry_delay(100)

      assert(delay <= 30000) -- max 30 seconds
    end)
  end)
end)
