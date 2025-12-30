--- port_select.lua - ポート選択メニュー（リモートポート自動検出・選択）

local M = {}

---@class PortInfo
---@field port number Container port number
---@field name string|nil Port name

---Extract container ports from pod spec
---@param pod table Pod resource with spec
---@param container_name? string Specific container name to filter
---@return PortInfo[] ports Port information list
function M.extract_container_ports(pod, container_name)
  local ports = {}

  if not pod.spec or not pod.spec.containers then
    return ports
  end

  for _, container in ipairs(pod.spec.containers) do
    -- Filter by container name if specified
    if not container_name or container.name == container_name then
      if container.ports then
        for _, port in ipairs(container.ports) do
          table.insert(ports, {
            port = port.containerPort,
            name = port.name,
          })
        end
      end
    end
  end

  return ports
end

---Check if port selection is needed
---@param ports PortInfo[] Port list
---@return boolean
function M.needs_selection(ports)
  return #ports > 1
end

---Get default port (first one)
---@param ports PortInfo[] Port list
---@return number|nil
function M.get_default_port(ports)
  if #ports == 0 then
    return nil
  end
  return ports[1].port
end

---@class PortMenuItem
---@field text string Display text
---@field value number Port number

---Create menu items from port list
---@param ports PortInfo[] Port list
---@return PortMenuItem[]
function M.create_menu_items(ports)
  local items = {}

  for _, port_info in ipairs(ports) do
    table.insert(items, {
      text = M.format_port_display(port_info.port, port_info.name),
      value = port_info.port,
    })
  end

  return items
end

---Format menu title
---@return string
function M.format_menu_title()
  return "Select Port"
end

---Validate port number
---@param port any Port to validate
---@return boolean
function M.validate_port(port)
  if type(port) ~= "number" then
    return false
  end

  return port >= 1 and port <= 65535
end

---Format port for display
---@param port number Port number
---@param name? string Port name
---@return string
function M.format_port_display(port, name)
  if name and name ~= "" then
    return string.format("%d (%s)", port, name)
  end
  return tostring(port)
end

return M
