local header = require("k8s.ui.components.header")

describe("header", function()
  describe("format", function()
    it("should format header with context, namespace and view", function()
      local text = header.format({
        context = "minikube",
        namespace = "default",
        view = "Pods",
      })

      assert.equals("[Context: minikube] [Namespace: default] [Pods]", text)
    end)

    it("should show 'All' when namespace is 'All Namespaces'", function()
      local text = header.format({
        context = "minikube",
        namespace = "All Namespaces",
        view = "Pods",
      })

      assert.equals("[Context: minikube] [Namespace: All] [Pods]", text)
    end)

    it("should append Loading... when loading is true", function()
      local text = header.format({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        loading = true,
      })

      assert.equals("[Context: minikube] [Namespace: default] [Pods] Loading...", text)
    end)

    it("should append filter text when provided", function()
      local text = header.format({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        filter = "nginx",
      })

      assert.equals("[Context: minikube] [Namespace: default] [Pods] Filter: nginx", text)
    end)

    it("should show both loading and filter", function()
      local text = header.format({
        context = "minikube",
        namespace = "default",
        view = "Pods",
        loading = true,
        filter = "nginx",
      })

      assert.equals("[Context: minikube] [Namespace: default] [Pods] Filter: nginx Loading...", text)
    end)
  end)
end)
