--- columns_spec.lua - カラム定義のテスト

local columns = require("k8s.views.columns")

describe("columns", function()
  describe("get_columns", function()
    it("should return columns for Pod", function()
      local cols = columns.get_columns("Pod")

      assert.equals(6, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("NAMESPACE", cols[2].header)
      assert.equals("STATUS", cols[3].header)
      assert.equals("READY", cols[4].header)
      assert.equals("RESTARTS", cols[5].header)
      assert.equals("AGE", cols[6].header)
    end)

    it("should return columns for Deployment", function()
      local cols = columns.get_columns("Deployment")

      assert.equals(6, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("NAMESPACE", cols[2].header)
      assert.equals("READY", cols[3].header)
      assert.equals("UP-TO-DATE", cols[4].header)
      assert.equals("AVAILABLE", cols[5].header)
      assert.equals("AGE", cols[6].header)
    end)

    it("should return columns for Service", function()
      local cols = columns.get_columns("Service")

      assert.equals(7, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("NAMESPACE", cols[2].header)
      assert.equals("TYPE", cols[3].header)
      assert.equals("CLUSTER-IP", cols[4].header)
      assert.equals("EXTERNAL-IP", cols[5].header)
      assert.equals("PORTS", cols[6].header)
      assert.equals("AGE", cols[7].header)
    end)

    it("should return columns for ConfigMap", function()
      local cols = columns.get_columns("ConfigMap")

      assert.equals(4, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("NAMESPACE", cols[2].header)
      assert.equals("DATA", cols[3].header)
      assert.equals("AGE", cols[4].header)
    end)

    it("should return columns for Secret", function()
      local cols = columns.get_columns("Secret")

      assert.equals(5, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("NAMESPACE", cols[2].header)
      assert.equals("TYPE", cols[3].header)
      assert.equals("DATA", cols[4].header)
      assert.equals("AGE", cols[5].header)
    end)

    it("should return columns for Node", function()
      local cols = columns.get_columns("Node")

      assert.equals(5, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("STATUS", cols[2].header)
      assert.equals("ROLES", cols[3].header)
      assert.equals("AGE", cols[4].header)
      assert.equals("VERSION", cols[5].header)
    end)

    it("should return columns for Namespace", function()
      local cols = columns.get_columns("Namespace")

      assert.equals(3, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("STATUS", cols[2].header)
      assert.equals("AGE", cols[3].header)
    end)

    it("should return columns for PortForward", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      local cols = columns.get_columns("PortForward")

      assert.equals(4, #cols)
      assert.equals("LOCAL", cols[1].header)
      assert.equals("REMOTE", cols[2].header)
      assert.equals("RESOURCE", cols[3].header)
      assert.equals("STATUS", cols[4].header)
    end)

    it("should return default columns for unknown kind", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      local cols = columns.get_columns("Unknown")

      assert.equals(4, #cols)
      assert.equals("NAME", cols[1].header)
      assert.equals("NAMESPACE", cols[2].header)
      assert.equals("STATUS", cols[3].header)
      assert.equals("AGE", cols[4].header)
    end)
  end)

  describe("extract_row", function()
    it("should extract Pod row data", function()
      local resource = {
        kind = "Pod",
        name = "nginx-pod",
        namespace = "default",
        status = "Running",
        age = "5d",
        raw = {
          status = {
            containerStatuses = {
              { ready = true, restartCount = 2 },
              { ready = true, restartCount = 1 },
            },
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("nginx-pod", row.name)
      assert.equals("default", row.namespace)
      assert.equals("Running", row.status)
      assert.equals("2/2", row.ready)
      assert.equals(3, row.restarts)
      assert.equals("5d", row.age)
    end)

    it("should extract Pod row with no container statuses", function()
      local resource = {
        kind = "Pod",
        name = "pending-pod",
        namespace = "default",
        status = "Pending",
        age = "1m",
        raw = {
          spec = {
            containers = { {}, {} },
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("0/2", row.ready)
      assert.equals(0, row.restarts)
    end)

    it("should extract Deployment row data", function()
      local resource = {
        kind = "Deployment",
        name = "nginx-deploy",
        namespace = "default",
        status = "3/3",
        age = "10d",
        raw = {
          spec = { replicas = 3 },
          status = {
            readyReplicas = 3,
            updatedReplicas = 3,
            availableReplicas = 3,
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("nginx-deploy", row.name)
      assert.equals("default", row.namespace)
      assert.equals("3/3", row.ready)
      assert.equals(3, row.up_to_date)
      assert.equals(3, row.available)
      assert.equals("10d", row.age)
    end)

    it("should extract Service row data", function()
      local resource = {
        kind = "Service",
        name = "nginx-svc",
        namespace = "default",
        status = "ClusterIP",
        age = "5d",
        raw = {
          spec = {
            type = "ClusterIP",
            clusterIP = "10.96.0.1",
            ports = {
              { port = 80, protocol = "TCP" },
              { port = 443, protocol = "TCP" },
            },
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("nginx-svc", row.name)
      assert.equals("ClusterIP", row.type)
      assert.equals("10.96.0.1", row.cluster_ip)
      assert.equals("<none>", row.external_ip)
      assert.equals("80/TCP,443/TCP", row.ports)
    end)

    it("should extract Service with LoadBalancer external IP", function()
      local resource = {
        kind = "Service",
        name = "lb-svc",
        namespace = "default",
        status = "LoadBalancer",
        age = "1d",
        raw = {
          spec = {
            type = "LoadBalancer",
            clusterIP = "10.96.0.2",
            ports = { { port = 80, protocol = "TCP" } },
          },
          status = {
            loadBalancer = {
              ingress = { { ip = "203.0.113.1" } },
            },
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("203.0.113.1", row.external_ip)
    end)

    it("should extract ConfigMap row data", function()
      local resource = {
        kind = "ConfigMap",
        name = "app-config",
        namespace = "default",
        status = "Active",
        age = "2d",
        raw = {
          data = {
            key1 = "value1",
            key2 = "value2",
            key3 = "value3",
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("app-config", row.name)
      assert.equals("default", row.namespace)
      assert.equals(3, row.data)
      assert.equals("2d", row.age)
    end)

    it("should extract ConfigMap with binaryData", function()
      local resource = {
        kind = "ConfigMap",
        name = "binary-config",
        namespace = "default",
        status = "Active",
        age = "1d",
        raw = {
          data = { key1 = "value1" },
          binaryData = { binary1 = "base64data" },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals(2, row.data)
    end)

    it("should extract Secret row data", function()
      local resource = {
        kind = "Secret",
        name = "app-secret",
        namespace = "default",
        status = "Active",
        age = "3d",
        raw = {
          type = "Opaque",
          data = {
            username = "YWRtaW4=",
            password = "cGFzc3dvcmQ=",
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("app-secret", row.name)
      assert.equals("Opaque", row.type)
      assert.equals(2, row.data)
      assert.equals("3d", row.age)
    end)

    it("should extract Node row data", function()
      local resource = {
        kind = "Node",
        name = "node-1",
        namespace = "",
        status = "Ready",
        age = "30d",
        raw = {
          metadata = {
            labels = {
              ["node-role.kubernetes.io/control-plane"] = "",
              ["node-role.kubernetes.io/master"] = "",
            },
          },
          status = {
            nodeInfo = {
              kubeletVersion = "v1.28.0",
            },
            conditions = {
              { type = "Ready", status = "True" },
            },
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("node-1", row.name)
      assert.equals("Ready", row.status)
      assert.equals("control-plane,master", row.roles)
      assert.equals("v1.28.0", row.version)
    end)

    it("should extract Node with no roles", function()
      local resource = {
        kind = "Node",
        name = "worker-1",
        namespace = "",
        status = "Ready",
        age = "10d",
        raw = {
          metadata = { labels = {} },
          status = {
            nodeInfo = { kubeletVersion = "v1.28.0" },
          },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("<none>", row.roles)
    end)

    it("should extract Namespace row data", function()
      local resource = {
        kind = "Namespace",
        name = "kube-system",
        namespace = "",
        status = "Active",
        age = "100d",
        raw = {
          status = { phase = "Active" },
        },
      }

      local row = columns.extract_row(resource)

      assert.equals("kube-system", row.name)
      assert.equals("Active", row.status)
      assert.equals("100d", row.age)
    end)

    it("should extract default row for unknown kind", function()
      local resource = {
        kind = "Unknown",
        name = "my-resource",
        namespace = "default",
        status = "Active",
        age = "1h",
        raw = {},
      }

      local row = columns.extract_row(resource)

      assert.equals("my-resource", row.name)
      assert.equals("default", row.namespace)
      assert.equals("Active", row.status)
      assert.equals("1h", row.age)
    end)
  end)

  describe("get_status_column_key", function()
    it("should return status key for Pod", function()
      assert.equals("status", columns.get_status_column_key("Pod"))
    end)

    it("should return status key for Deployment", function()
      assert.equals("ready", columns.get_status_column_key("Deployment"))
    end)

    it("should return status key for Node", function()
      assert.equals("status", columns.get_status_column_key("Node"))
    end)

    it("should return status for unknown kind", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.equals("status", columns.get_status_column_key("Unknown"))
    end)
  end)
end)
