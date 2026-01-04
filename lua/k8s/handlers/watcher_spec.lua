--- watcher_spec.lua - Watcher ライフサイクル管理のテスト

describe("watcher", function()
  local state
  local watcher
  local watch_adapter
  local original_watch
  local original_stop

  before_each(function()
    -- Clear all cached modules
    package.loaded["k8s.handlers.watcher"] = nil
    package.loaded["k8s.adapters.kubectl.watch"] = nil
    package.loaded["k8s.state"] = nil
    package.loaded["k8s.state.init"] = nil
    package.loaded["k8s.state.global"] = nil
    package.loaded["k8s.state.view"] = nil

    -- Load state first and reset
    state = require("k8s.state")
    state.reset()

    -- Get watch_adapter and save originals
    watch_adapter = require("k8s.adapters.kubectl.watch")
    original_watch = watch_adapter.watch
    original_stop = watch_adapter.stop

    -- Load watcher last (it will use the same watch_adapter table)
    watcher = require("k8s.handlers.watcher")
  end)

  after_each(function()
    -- Restore original functions
    watch_adapter.watch = original_watch
    watch_adapter.stop = original_stop
  end)

  describe("start", function()
    it("should call watch_adapter.watch with correct parameters", function()
      local captured_kind = nil
      local captured_namespace = nil
      watch_adapter.watch = function(kind, namespace, _)
        captured_kind = kind
        captured_namespace = namespace
        return 12345
      end

      -- Setup view
      state.push_view({ type = "pod_list", resources = {} })

      watcher.start("Pod", "default", {})

      assert.equals("pods", captured_kind)
      assert.equals("default", captured_namespace)
    end)

    it("should set watcher job_id in state", function()
      watch_adapter.watch = function(_, _, _)
        return 12345
      end

      state.push_view({ type = "pod_list", resources = {} })

      watcher.start("Pod", "default", {})

      local current = state.get_current_view()
      assert(current)
      assert.equals(12345, current.watcher_job_id)
    end)

    it("should return job_id", function()
      watch_adapter.watch = function(_, _, _)
        return 99999
      end

      state.push_view({ type = "pod_list", resources = {} })

      local job_id = watcher.start("Pod", "default", {})

      assert.equals(99999, job_id)
    end)

    it("should call on_started callback", function()
      local on_started_called = false
      watch_adapter.watch = function(_, _, opts)
        if opts.on_started then
          opts.on_started()
        end
        return 12345
      end

      state.push_view({ type = "pod_list", resources = {} })

      watcher.start("Pod", "default", {
        on_started = function()
          on_started_called = true
        end,
      })

      assert.is_true(on_started_called)
    end)
  end)

  describe("stop", function()
    it("should call watch_adapter.stop with job_id", function()
      local stopped_job_id = nil
      watch_adapter.watch = function(_, _, _)
        return 12345
      end
      watch_adapter.stop = function(job_id)
        stopped_job_id = job_id
      end

      state.push_view({ type = "pod_list", resources = {} })
      watcher.start("Pod", "default", {})

      watcher.stop()

      assert.equals(12345, stopped_job_id)
    end)

    it("should clear watcher job_id from state", function()
      watch_adapter.watch = function(_, _, _)
        return 12345
      end
      watch_adapter.stop = function(_) end

      state.push_view({ type = "pod_list", resources = {} })
      watcher.start("Pod", "default", {})

      watcher.stop()

      local current = state.get_current_view()
      assert(current)
      assert.is_nil(current.watcher_job_id)
    end)

    it("should not error when no watcher is running", function()
      watch_adapter.stop = function(_) end

      state.push_view({ type = "pod_list", resources = {} })

      -- Should not throw error
      watcher.stop()
    end)
  end)

  describe("restart", function()
    it("should stop and start watcher", function()
      local stop_called = false
      local start_kind = nil
      watch_adapter.watch = function(kind, _, _)
        start_kind = kind
        return 12345
      end
      watch_adapter.stop = function(_)
        stop_called = true
      end

      state.push_view({ type = "deployment_list", resources = {} })
      state.set_watcher_job_id(11111) -- Simulate existing watcher

      watcher.restart({})

      assert.is_true(stop_called)
      assert.equals("deployments", start_kind)
    end)

    it("should not start watcher when no current view", function()
      local watch_called = false
      watch_adapter.watch = function(_, _, _)
        watch_called = true
        return 12345
      end
      watch_adapter.stop = function(_) end

      -- No view pushed

      watcher.restart({})

      assert.is_false(watch_called)
    end)

    it("should use field_selector from view state", function()
      local captured_opts = nil
      watch_adapter.watch = function(_, _, _, opts)
        captured_opts = opts
        return 12345
      end
      watch_adapter.stop = function(_) end

      -- Push view with field_selector
      state.push_view({
        type = "event_list",
        resources = {},
        field_selector = "involvedObject.name=my-pod,involvedObject.kind=Pod",
      })

      watcher.restart({})

      assert(captured_opts)
      assert.equals("involvedObject.name=my-pod,involvedObject.kind=Pod", captured_opts.field_selector)
    end)
  end)
end)
