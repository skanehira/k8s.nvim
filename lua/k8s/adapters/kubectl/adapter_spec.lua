local adapter = require("k8s.adapters.kubectl.adapter")

describe("adapter", function()
  describe("get_resources", function()
    it("should return resources for pods", function()
      -- モックを設定
      local mock_output = [[
{
  "apiVersion": "v1",
  "kind": "PodList",
  "items": [
    {
      "metadata": {
        "name": "nginx-abc123",
        "namespace": "default",
        "creationTimestamp": "2024-12-30T10:00:00Z"
      },
      "status": {
        "phase": "Running"
      }
    }
  ]
}
]]
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = mock_output, stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.get_resources("pods", "default", function(res)
        result = res
      end)

      assert.is_true(result.ok)
      assert.equals(1, #result.data)
      assert.equals("nginx-abc123", result.data[1].name)
      assert.equals("default", result.data[1].namespace)
      assert.equals("Pod", result.data[1].kind)
    end)

    it("should handle kubectl errors", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 1, stdout = "", stderr = "error: resource not found" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.get_resources("pods", "nonexistent", function(res)
        result = res
      end)

      assert.is_false(result.ok)
      assert.is.Not.Nil(result.error)
    end)

    it("should use --all-namespaces when namespace is 'All Namespaces'", function()
      local captured_cmd
      adapter._set_executor(function(cmd, _, callback)
        captured_cmd = cmd
        if callback then
          callback({ code = 0, stdout = '{"kind":"PodList","items":[]}', stderr = "" })
        end
        return { wait = function() end }
      end)

      adapter.get_resources("pods", "All Namespaces", function() end)

      assert.is.Not.Nil(captured_cmd)
      local has_all_namespaces = false
      for _, arg in ipairs(captured_cmd) do
        if arg == "--all-namespaces" then
          has_all_namespaces = true
          break
        end
      end
      assert.is_true(has_all_namespaces)
    end)

    it("should include namespace flag when namespace is provided", function()
      local captured_cmd
      adapter._set_executor(function(cmd, _, callback)
        captured_cmd = cmd
        if callback then
          callback({ code = 0, stdout = '{"kind":"PodList","items":[]}', stderr = "" })
        end
        return { wait = function() end }
      end)

      adapter.get_resources("pods", "kube-system", function() end)

      local has_namespace = false
      for i, arg in ipairs(captured_cmd) do
        if arg == "-n" and captured_cmd[i + 1] == "kube-system" then
          has_namespace = true
          break
        end
      end
      assert.is_true(has_namespace)
    end)
  end)

  describe("describe", function()
    it("should return describe output", function()
      local mock_output = [[
Name:         nginx-abc123
Namespace:    default
Priority:     0
Node:         minikube/192.168.49.2
]]
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = mock_output, stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.describe("pod", "nginx-abc123", "default", function(res)
        result = res
      end)

      assert.is_true(result.ok)
      assert.equals(mock_output, result.data)
    end)

    it("should handle kubectl errors", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 1, stdout = "", stderr = 'Error from server (NotFound): pods "nonexistent" not found' })
        end
        return { wait = function() end }
      end)

      local result
      adapter.describe("pod", "nonexistent", "default", function(res)
        result = res
      end)

      assert.is_false(result.ok)
      assert.is.Not.Nil(result.error)
    end)

    it("should build correct command", function()
      local captured_cmd
      adapter._set_executor(function(cmd, _, callback)
        captured_cmd = cmd
        if callback then
          callback({ code = 0, stdout = "", stderr = "" })
        end
        return { wait = function() end }
      end)

      adapter.describe("deployment", "nginx-deploy", "kube-system", function() end)

      assert.is.Not.Nil(captured_cmd)
      -- kubectl describe deployment nginx-deploy -n kube-system
      assert.equals("kubectl", captured_cmd[1])
      assert.equals("describe", captured_cmd[2])
      assert.equals("deployment", captured_cmd[3])
      assert.equals("nginx-deploy", captured_cmd[4])
    end)
  end)

  describe("delete", function()
    it("should delete a resource", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = 'pod "nginx-abc123" deleted', stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.delete("pod", "nginx-abc123", "default", function(res)
        result = res
      end)

      assert.is_true(result.ok)
    end)

    it("should handle errors", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 1, stdout = "", stderr = "Error from server (NotFound)" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.delete("pod", "nonexistent", "default", function(res)
        result = res
      end)

      assert.is_false(result.ok)
    end)

    it("should build correct command", function()
      local captured_cmd
      adapter._set_executor(function(cmd, _, callback)
        captured_cmd = cmd
        if callback then
          callback({ code = 0, stdout = "", stderr = "" })
        end
        return { wait = function() end }
      end)

      adapter.delete("pod", "nginx-abc123", "kube-system", function() end)

      assert.equals("kubectl", captured_cmd[1])
      assert.equals("delete", captured_cmd[2])
      assert.equals("pod", captured_cmd[3])
      assert.equals("nginx-abc123", captured_cmd[4])
    end)
  end)

  describe("scale", function()
    it("should scale a deployment", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = "deployment.apps/nginx-deploy scaled", stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.scale("deployment", "nginx-deploy", "default", 3, function(res)
        result = res
      end)

      assert.is_true(result.ok)
    end)

    it("should build correct command with replicas", function()
      local captured_cmd
      adapter._set_executor(function(cmd, _, callback)
        captured_cmd = cmd
        if callback then
          callback({ code = 0, stdout = "", stderr = "" })
        end
        return { wait = function() end }
      end)

      adapter.scale("deployment", "nginx-deploy", "default", 5, function() end)

      assert.equals("kubectl", captured_cmd[1])
      assert.equals("scale", captured_cmd[2])
      assert.equals("deployment", captured_cmd[3])
      assert.equals("nginx-deploy", captured_cmd[4])
      -- Check for --replicas=5
      local has_replicas = false
      for _, arg in ipairs(captured_cmd) do
        if arg == "--replicas=5" then
          has_replicas = true
          break
        end
      end
      assert.is_true(has_replicas)
    end)
  end)

  describe("restart", function()
    it("should restart a deployment", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = "deployment.apps/nginx-deploy restarted", stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.restart("deployment", "nginx-deploy", "default", function(res)
        result = res
      end)

      assert.is_true(result.ok)
    end)

    it("should build correct command", function()
      local captured_cmd
      adapter._set_executor(function(cmd, _, callback)
        captured_cmd = cmd
        if callback then
          callback({ code = 0, stdout = "", stderr = "" })
        end
        return { wait = function() end }
      end)

      adapter.restart("deployment", "nginx-deploy", "default", function() end)

      assert.equals("kubectl", captured_cmd[1])
      assert.equals("rollout", captured_cmd[2])
      assert.equals("restart", captured_cmd[3])
      assert.equals("deployment", captured_cmd[4])
      assert.equals("nginx-deploy", captured_cmd[5])
    end)
  end)

  describe("exec", function()
    it("should build correct command", function()
      local captured_cmd
      adapter._set_term_opener(function(cmd)
        captured_cmd = cmd
        return 12345 -- mock job id
      end)

      local result = adapter.exec("nginx-abc123", "nginx", "default")

      assert.is_true(result.ok)
      assert.equals(12345, result.data.job_id)
      assert.is.not_nil(captured_cmd)
      -- kubectl exec -it -n default nginx-abc123 -c nginx -- sh
      local cmd_str = captured_cmd
      assert.is_true(cmd_str:find("kubectl") ~= nil)
      assert.is_true(cmd_str:find("exec") ~= nil)
      assert.is_true(cmd_str:find("nginx%-abc123") ~= nil)
      assert.is_true(cmd_str:find("%-c nginx") ~= nil)
    end)

    it("should use auto-detect shell command as default", function()
      local captured_cmd
      adapter._set_term_opener(function(cmd)
        captured_cmd = cmd
        return 12345
      end)

      adapter.exec("nginx-abc123", "nginx", "default")

      -- Should use sh -c "[ -e /bin/bash ] && exec bash || exec sh" for auto-detection
      assert.is_true(captured_cmd:find("sh %-c") ~= nil, "Should use sh -c for auto-detection")
      assert.is_true(captured_cmd:find("/bin/bash") ~= nil, "Should check for /bin/bash")
    end)

    it("should pass on_exit callback to term opener", function()
      local captured_opts
      adapter._set_term_opener(function(_, opts)
        captured_opts = opts
        return 12345
      end)

      local on_exit = function() end
      adapter.exec("nginx-abc123", "nginx", "default", nil, { on_exit = on_exit })

      assert.is.Not.Nil(captured_opts)
      assert.equals(on_exit, captured_opts.on_exit)
    end)
  end)

  describe("logs", function()
    it("should build correct command", function()
      local captured_cmd
      adapter._set_term_opener(function(cmd)
        captured_cmd = cmd
        return 12345
      end)

      local result = adapter.logs("nginx-abc123", "nginx", "default", {})

      assert.is_true(result.ok)
      assert.equals(12345, result.data.job_id)
      assert.is_true(captured_cmd:find("kubectl") ~= nil)
      assert.is_true(captured_cmd:find("logs") ~= nil)
      assert.is_true(captured_cmd:find("nginx%-abc123") ~= nil)
    end)

    it("should add -f flag when follow is true", function()
      local captured_cmd
      adapter._set_term_opener(function(cmd)
        captured_cmd = cmd
        return 12345
      end)

      adapter.logs("nginx-abc123", "nginx", "default", { follow = true })

      assert.is_true(captured_cmd:find("%-f") ~= nil)
    end)

    it("should add --timestamps flag when timestamps is true", function()
      local captured_cmd
      adapter._set_term_opener(function(cmd)
        captured_cmd = cmd
        return 12345
      end)

      adapter.logs("nginx-abc123", "nginx", "default", { timestamps = true })

      assert.is_true(captured_cmd:find("%-%-timestamps") ~= nil)
    end)

    it("should add -p flag when previous is true", function()
      local captured_cmd
      adapter._set_term_opener(function(cmd)
        captured_cmd = cmd
        return 12345
      end)

      adapter.logs("nginx-abc123", "nginx", "default", { previous = true })

      assert.is_true(captured_cmd:find("%-p") ~= nil)
    end)
  end)

  describe("debug", function()
    it("should build correct command", function()
      local captured_cmd
      adapter._set_term_opener(function(cmd)
        captured_cmd = cmd
        return 12345
      end)

      local result = adapter.debug("nginx-abc123", "nginx", "default", "busybox")

      assert.is_true(result.ok)
      assert.equals(12345, result.data.job_id)
      assert.is.not_nil(captured_cmd)
      -- kubectl debug -it -n default nginx-abc123 --target=nginx --profile=sysadmin --image=busybox -- sh
      assert.is_true(captured_cmd:find("kubectl") ~= nil)
      assert.is_true(captured_cmd:find("debug") ~= nil)
      assert.is_true(captured_cmd:find("nginx%-abc123") ~= nil)
      assert.is_true(captured_cmd:find("%-%-target=nginx") ~= nil)
      assert.is_true(captured_cmd:find("%-%-profile=sysadmin") ~= nil)
      assert.is_true(captured_cmd:find("%-%-image=busybox") ~= nil)
    end)

    it("should pass tab_name to term opener", function()
      local captured_opts
      adapter._set_term_opener(function(_, opts)
        captured_opts = opts
        return 12345
      end)

      adapter.debug("nginx-abc123", "nginx", "default", "busybox", { tab_name = "[Debug] nginx-abc123:nginx" })

      assert.is.Not.Nil(captured_opts)
      assert.equals("[Debug] nginx-abc123:nginx", captured_opts.tab_name)
    end)

    it("should pass on_exit callback to term opener", function()
      local captured_opts
      adapter._set_term_opener(function(_, opts)
        captured_opts = opts
        return 12345
      end)

      local on_exit = function() end
      adapter.debug("nginx-abc123", "nginx", "default", "busybox", { on_exit = on_exit })

      assert.is.Not.Nil(captured_opts)
      assert.equals(on_exit, captured_opts.on_exit)
    end)
  end)

  describe("port_forward", function()
    it("should build correct command", function()
      local captured_cmd
      adapter._set_job_starter(function(cmd)
        captured_cmd = cmd
        return 12345
      end)

      local result = adapter.port_forward("pod/nginx-abc123", "default", 8080, 80)

      assert.is_true(result.ok)
      assert.equals(12345, result.data.job_id)
      -- cmd is now a table
      assert.equals("kubectl", captured_cmd[1])
      assert.equals("port-forward", captured_cmd[2])
      assert.equals("-n", captured_cmd[3])
      assert.equals("default", captured_cmd[4])
      assert.equals("pod/nginx-abc123", captured_cmd[5])
      assert.equals("8080:80", captured_cmd[6])
    end)

    it("should return error when job fails to start", function()
      adapter._set_job_starter(function()
        return 0 -- 0 means failure
      end)

      local result = adapter.port_forward("pod/nginx-abc123", "default", 8080, 80)

      assert.is_false(result.ok)
      assert.is.Not.Nil(result.error)
    end)
  end)

  describe("check_connection", function()
    it("should return ok when connection succeeds", function()
      adapter._set_executor(function(_, _)
        return {
          wait = function()
            return { code = 0, stdout = "Client Version: ...\nServer Version: ...", stderr = "" }
          end,
        }
      end)

      local result = adapter.check_connection()

      assert.is_true(result.ok)
      assert.is_nil(result.error)
    end)

    it("should return error when connection fails", function()
      adapter._set_executor(function(_, _)
        return {
          wait = function()
            return {
              code = 1,
              stdout = "",
              stderr = "Unable to connect to the server: dial tcp 127.0.0.1:6443: connect: connection refused",
            }
          end,
        }
      end)

      local result = adapter.check_connection()

      assert.is_false(result.ok)
      assert(result.error)
      assert.is_true(result.error:find("Unable to connect") ~= nil)
    end)

    it("should use fallback message when stderr is nil", function()
      adapter._set_executor(function(_, _)
        return {
          wait = function()
            return { code = 1, stdout = "", stderr = nil }
          end,
        }
      end)

      local result = adapter.check_connection()

      assert.is_false(result.ok)
      assert(result.error)
      assert.equals("Failed to connect to Kubernetes cluster", result.error)
    end)

    it("should pass correct command arguments", function()
      local captured_cmd, captured_opts
      adapter._set_executor(function(cmd, opts)
        captured_cmd = cmd
        captured_opts = opts
        return {
          wait = function()
            return { code = 0, stdout = "", stderr = "" }
          end,
        }
      end)

      adapter.check_connection()

      assert(captured_cmd)
      assert.equals("kubectl", captured_cmd[1])
      assert.equals("version", captured_cmd[2])
      assert.equals("--request-timeout=5s", captured_cmd[3])
      assert(captured_opts)
      assert.is_true(captured_opts.text)
    end)
  end)

  describe("get_contexts", function()
    it("should return list of contexts", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = "minikube\ndocker-desktop\nproduction", stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.get_contexts(function(res)
        result = res
      end)

      assert.is_true(result.ok)
      assert.equals(3, #result.data)
      assert.equals("minikube", result.data[1])
      assert.equals("docker-desktop", result.data[2])
      assert.equals("production", result.data[3])
    end)

    it("should handle errors", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 1, stdout = "", stderr = "error: no contexts" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.get_contexts(function(res)
        result = res
      end)

      assert.is_false(result.ok)
    end)
  end)

  describe("use_context", function()
    it("should switch context", function()
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = 'Switched to context "minikube".', stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.use_context("minikube", function(res)
        result = res
      end)

      assert.is_true(result.ok)
    end)

    it("should build correct command", function()
      local captured_cmd
      adapter._set_executor(function(cmd, _, callback)
        captured_cmd = cmd
        if callback then
          callback({ code = 0, stdout = "", stderr = "" })
        end
        return { wait = function() end }
      end)

      adapter.use_context("production", function() end)

      assert.equals("kubectl", captured_cmd[1])
      assert.equals("config", captured_cmd[2])
      assert.equals("use-context", captured_cmd[3])
      assert.equals("production", captured_cmd[4])
    end)
  end)

  describe("get_namespaces", function()
    it("should return list of namespaces", function()
      local mock_output = [[
{
  "apiVersion": "v1",
  "kind": "NamespaceList",
  "items": [
    {"metadata": {"name": "default"}},
    {"metadata": {"name": "kube-system"}},
    {"metadata": {"name": "monitoring"}}
  ]
}
]]
      adapter._set_executor(function(_, _, callback)
        if callback then
          callback({ code = 0, stdout = mock_output, stderr = "" })
        end
        return { wait = function() end }
      end)

      local result
      adapter.get_namespaces(function(res)
        result = res
      end)

      assert.is_true(result.ok)
      assert.equals(3, #result.data)
      assert.equals("default", result.data[1])
      assert.equals("kube-system", result.data[2])
      assert.equals("monitoring", result.data[3])
    end)
  end)

  -- テスト後にexecutorをリセット
  after_each(function()
    adapter._reset_executor()
    adapter._reset_term_opener()
    adapter._reset_job_starter()
  end)
end)
