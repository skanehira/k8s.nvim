--- timer_spec.lua - 自動更新タイマーのテスト

local timer = require("k8s.ui.nui.timer")

describe("timer", function()
  describe("create_timer_config", function()
    it("should create default timer config", function()
      local config = timer.create_timer_config()

      assert.equals(5000, config.interval)
      assert.is_true(config.repeat_timer)
    end)

    it("should accept custom interval", function()
      local config = timer.create_timer_config({ interval = 10000 })

      assert.equals(10000, config.interval)
    end)

    it("should accept interval in seconds", function()
      local config = timer.create_timer_config({ interval_seconds = 3 })

      assert.equals(3000, config.interval)
    end)
  end)

  describe("validate_interval", function()
    it("should return true for valid interval", function()
      assert.is_true(timer.validate_interval(1000))
      assert.is_true(timer.validate_interval(5000))
      assert.is_true(timer.validate_interval(60000))
    end)

    it("should return false for too small interval", function()
      assert.is_false(timer.validate_interval(100))
      assert.is_false(timer.validate_interval(0))
      assert.is_false(timer.validate_interval(-1000))
    end)

    it("should return false for too large interval", function()
      assert.is_false(timer.validate_interval(600001))
      assert.is_false(timer.validate_interval(1000000))
    end)

    it("should return false for non-number", function()
      assert.is_false(timer.validate_interval("5000"))
      assert.is_false(timer.validate_interval(nil))
    end)
  end)

  describe("create_timer_state", function()
    it("should create initial timer state", function()
      local state = timer.create_timer_state()

      assert.is_false(state.running)
      assert.is_nil(state.handle)
      assert.is_nil(state.last_tick)
    end)
  end)

  describe("update_timer_state", function()
    it("should update state to running", function()
      local state = timer.create_timer_state()

      local updated = timer.update_timer_state(state, {
        running = true,
        handle = "mock_handle",
      })

      assert.is_true(updated.running)
      assert.equals("mock_handle", updated.handle)
    end)

    it("should update last_tick", function()
      local state = timer.create_timer_state()
      local now = os.time()

      local updated = timer.update_timer_state(state, {
        last_tick = now,
      })

      assert.equals(now, updated.last_tick)
    end)

    it("should not modify original state", function()
      local state = timer.create_timer_state()

      timer.update_timer_state(state, { running = true })

      assert.is_false(state.running)
    end)
  end)

  describe("calculate_next_tick", function()
    it("should calculate next tick time", function()
      local last_tick = 1000000
      local interval = 5000

      local next_tick = timer.calculate_next_tick(last_tick, interval)

      assert.equals(1005000, next_tick)
    end)
  end)

  describe("should_tick", function()
    it("should return true when interval has passed", function()
      local last_tick = 1000
      local current = 6001
      local interval = 5000

      assert.is_true(timer.should_tick(last_tick, current, interval))
    end)

    it("should return false when interval has not passed", function()
      local last_tick = 1000
      local current = 4000
      local interval = 5000

      assert.is_false(timer.should_tick(last_tick, current, interval))
    end)

    it("should return true for first tick", function()
      local last_tick = nil
      local current = 1000
      local interval = 5000

      assert.is_true(timer.should_tick(last_tick, current, interval))
    end)
  end)

  describe("create_tick_callback", function()
    it("should create callback that invokes handler", function()
      local called = false

      local handler = function()
        called = true
      end

      local callback = timer.create_tick_callback(handler)
      callback()

      assert.is_true(called)
    end)

    it("should handle errors gracefully", function()
      local error_handled = false

      local handler = function()
        error("test error")
      end

      local on_error = function()
        error_handled = true
      end

      local callback = timer.create_tick_callback(handler, on_error)
      callback()

      assert.is_true(error_handled)
    end)
  end)

  describe("format_interval", function()
    it("should format interval in seconds", function()
      assert.equals("5s", timer.format_interval(5000))
      assert.equals("10s", timer.format_interval(10000))
    end)

    it("should format interval in minutes", function()
      assert.equals("1m", timer.format_interval(60000))
      assert.equals("2m", timer.format_interval(120000))
    end)

    it("should format mixed interval", function()
      assert.equals("1m 30s", timer.format_interval(90000))
    end)
  end)

  describe("get_default_interval", function()
    it("should return default interval of 5 seconds", function()
      assert.equals(5000, timer.get_default_interval())
    end)
  end)
end)
