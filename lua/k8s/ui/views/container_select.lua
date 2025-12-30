--- container_select.lua - コンテナ選択メニュー（複数コンテナ時の選択UI）

local M = {}

---Extract container names from pod spec
---@param pod table Pod resource with spec
---@param opts? { include_init?: boolean } Options
---@return string[] containers Container names
function M.extract_containers(pod, opts)
  opts = opts or {}
  local containers = {}

  if not pod.spec then
    return containers
  end

  -- Include init containers if requested
  if opts.include_init and pod.spec.initContainers then
    for _, container in ipairs(pod.spec.initContainers) do
      table.insert(containers, container.name)
    end
  end

  -- Regular containers
  if pod.spec.containers then
    for _, container in ipairs(pod.spec.containers) do
      table.insert(containers, container.name)
    end
  end

  return containers
end

---Check if container selection is needed
---@param containers string[] Container names
---@return boolean
function M.needs_selection(containers)
  return #containers > 1
end

---Get default container (first one)
---@param containers string[] Container names
---@return string|nil
function M.get_default_container(containers)
  if #containers == 0 then
    return nil
  end
  return containers[1]
end

---@class MenuItem
---@field text string Display text
---@field value string Value to return on selection

---Create menu items from container names
---@param containers string[] Container names
---@return MenuItem[]
function M.create_menu_items(containers)
  local items = {}

  for _, name in ipairs(containers) do
    table.insert(items, {
      text = name,
      value = name,
    })
  end

  return items
end

---Format menu title
---@return string
function M.format_menu_title()
  return "Select Container"
end

---Validate container name exists in list
---@param containers string[] Available containers
---@param name string|nil Container name to validate
---@return boolean
function M.validate_container_name(containers, name)
  if not name then
    return false
  end

  for _, container in ipairs(containers) do
    if container == name then
      return true
    end
  end

  return false
end

return M
