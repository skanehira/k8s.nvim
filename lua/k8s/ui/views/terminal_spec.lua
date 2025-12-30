--- terminal_spec.lua - ターミナル管理モジュールのテスト

local terminal = require("k8s.ui.views.terminal")

describe("terminal", function()
  describe("create_tab_name", function()
    it("should create tab name for logs", function()
      local name = terminal.create_tab_name("logs", "nginx-abc123")
      assert.equals("[logs] nginx-abc123", name)
    end)

    it("should create tab name for exec", function()
      local name = terminal.create_tab_name("exec", "redis-def456")
      assert.equals("[exec] redis-def456", name)
    end)

    it("should handle container suffix", function()
      local name = terminal.create_tab_name("logs", "nginx-abc123", "app")
      assert.equals("[logs] nginx-abc123/app", name)
    end)
  end)

  describe("build_logs_command", function()
    it("should build basic logs command", function()
      local cmd = terminal.build_logs_command({
        pod = "nginx-abc123",
        namespace = "default",
      })

      assert(cmd:find("kubectl"))
      assert(cmd:find("logs"))
      assert(cmd:find("nginx%-abc123"))
      assert(cmd:find("%-n%s+default") or cmd:find("%-%-namespace"))
      assert(cmd:find("%-f")) -- follow mode
      assert(cmd:find("%-%-timestamps"))
    end)

    it("should include container when specified", function()
      local cmd = terminal.build_logs_command({
        pod = "nginx-abc123",
        namespace = "default",
        container = "app",
      })

      assert(cmd:find("%-c%s+app") or cmd:find("%-%-container"))
    end)

    it("should include previous flag when specified", function()
      local cmd = terminal.build_logs_command({
        pod = "nginx-abc123",
        namespace = "default",
        previous = true,
      })

      assert(cmd:find("%-p") or cmd:find("%-%-previous"))
    end)

    it("should not include follow when previous is true", function()
      local cmd = terminal.build_logs_command({
        pod = "nginx-abc123",
        namespace = "default",
        previous = true,
      })

      -- When viewing previous logs, -f should not be used
      assert.is_nil(cmd:find("%-f%s") or cmd:find("%-f$"))
    end)
  end)

  describe("build_exec_command", function()
    it("should build exec command with shell auto-detection", function()
      local cmd = terminal.build_exec_command({
        pod = "nginx-abc123",
        namespace = "default",
      })

      assert(cmd:find("kubectl"))
      assert(cmd:find("exec"))
      assert(cmd:find("%-it"))
      assert(cmd:find("nginx%-abc123"))
      -- Shell auto-detection pattern
      assert(cmd:find("bash") or cmd:find("sh"))
    end)

    it("should include container when specified", function()
      local cmd = terminal.build_exec_command({
        pod = "nginx-abc123",
        namespace = "default",
        container = "sidecar",
      })

      assert(cmd:find("%-c%s+sidecar") or cmd:find("%-%-container"))
    end)

    it("should use provided shell command", function()
      local cmd = terminal.build_exec_command({
        pod = "nginx-abc123",
        namespace = "default",
        shell = "/bin/zsh",
      })

      assert(cmd:find("/bin/zsh"))
    end)
  end)

  describe("create_terminal_state", function()
    it("should create initial terminal state", function()
      local state = terminal.create_terminal_state()

      assert(state)
      assert.is_nil(state.job_id)
      assert.is_nil(state.tab_id)
      assert.is_nil(state.bufnr)
      assert.equals("", state.type)
      assert.equals("", state.pod_name)
    end)
  end)

  describe("parse_terminal_type", function()
    it("should parse logs type from tab name", function()
      local result = terminal.parse_terminal_type("[logs] nginx-abc123")
      assert(result)
      assert.equals("logs", result.type)
      assert.equals("nginx-abc123", result.pod_name)
    end)

    it("should parse exec type from tab name", function()
      local result = terminal.parse_terminal_type("[exec] redis-def456")
      assert(result)
      assert.equals("exec", result.type)
      assert.equals("redis-def456", result.pod_name)
    end)

    it("should parse pod name with container", function()
      local result = terminal.parse_terminal_type("[logs] nginx-abc123/app")
      assert(result)
      assert.equals("logs", result.type)
      assert.equals("nginx-abc123/app", result.pod_name)
    end)

    it("should return nil for invalid tab name", function()
      local result = terminal.parse_terminal_type("some-other-tab")
      assert.is_nil(result)
    end)
  end)

  describe("should_auto_close", function()
    it("should return true for exec terminals", function()
      local result = terminal.should_auto_close("exec")
      assert.is_true(result)
    end)

    it("should return false for logs terminals", function()
      local result = terminal.should_auto_close("logs")
      assert.is_false(result)
    end)
  end)

  describe("get_shell_command", function()
    it("should return auto-detection shell command by default", function()
      local cmd = terminal.get_shell_command()
      assert(cmd:find("bash") and cmd:find("sh"))
    end)

    it("should return provided shell command", function()
      local cmd = terminal.get_shell_command("/bin/zsh")
      assert.equals("/bin/zsh", cmd)
    end)
  end)

  describe("create_on_exit_callback", function()
    it("should create callback function for exec", function()
      local close_fn = function() end

      local callback = terminal.create_on_exit_callback("exec", close_fn)
      assert.is_function(callback)
    end)

    it("should create callback function for logs", function()
      local close_fn = function() end

      local callback = terminal.create_on_exit_callback("logs", close_fn)
      assert.is_function(callback)
    end)
  end)

  describe("validate_logs_options", function()
    it("should return true for valid options", function()
      local valid, err = terminal.validate_logs_options({
        pod = "nginx",
        namespace = "default",
      })
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false when pod is missing", function()
      local valid, err = terminal.validate_logs_options({
        namespace = "default",
      })
      assert.is_false(valid)
      assert(err)
      assert(err:find("pod"))
    end)

    it("should return false when namespace is missing", function()
      local valid, err = terminal.validate_logs_options({
        pod = "nginx",
      })
      assert.is_false(valid)
      assert(err)
      assert(err:find("namespace"))
    end)
  end)

  describe("validate_exec_options", function()
    it("should return true for valid options", function()
      local valid, err = terminal.validate_exec_options({
        pod = "nginx",
        namespace = "default",
      })
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should return false when pod is missing", function()
      local valid, err = terminal.validate_exec_options({
        namespace = "default",
      })
      assert.is_false(valid)
      assert(err)
      assert(err:find("pod"))
    end)
  end)
end)
