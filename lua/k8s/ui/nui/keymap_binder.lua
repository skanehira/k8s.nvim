--- keymap_binder.lua - キーマップバインダー

local M = {}

-- Special key normalization map
local special_keys = {
  ["<cr>"] = "<CR>",
  ["<esc>"] = "<Esc>",
  ["<tab>"] = "<Tab>",
  ["<bs>"] = "<BS>",
  ["<space>"] = "<Space>",
  ["<up>"] = "<Up>",
  ["<down>"] = "<Down>",
  ["<left>"] = "<Left>",
  ["<right>"] = "<Right>",
}

---Normalize key representation
---@param key string
---@return string
function M.normalize_key(key)
  local lower = key:lower()

  -- Check special keys
  if special_keys[lower] then
    return special_keys[lower]
  end

  -- Handle Ctrl combinations
  local ctrl_match = lower:match("^<c%-(.+)>$")
  if ctrl_match then
    return string.format("<C-%s>", ctrl_match)
  end

  return key
end

---Validate keymap definition
---@param def table
---@return boolean valid
---@return string|nil error
function M.validate_keymap_definition(def)
  if not def.key or def.key == "" then
    return false, "key is required"
  end

  if not def.action or def.action == "" then
    return false, "action is required"
  end

  return true, nil
end

---Create keymap config from definition
---@param def { key: string, action: string, desc?: string, mode?: string }
---@return table config
function M.create_keymap_config(def)
  return {
    key = def.key,
    action = def.action,
    mode = def.mode or "n",
    opts = {
      desc = def.desc or def.action,
      noremap = true,
      silent = true,
    },
  }
end

---Create handler wrapper that includes context
---@param handler function
---@param context table
---@return function wrapper
function M.create_handler_wrapper(handler, context)
  return function(...)
    return handler(context, ...)
  end
end

---Create keymap configs from definitions list
---@param defs table[]
---@return table[] configs
function M.create_keymaps_from_definitions(defs)
  local configs = {}

  for _, def in ipairs(defs) do
    local valid = M.validate_keymap_definition(def)
    if valid then
      table.insert(configs, M.create_keymap_config(def))
    end
  end

  return configs
end

---Get action for key
---@param keymaps table[]
---@param key string
---@return string|nil action
function M.get_action_for_key(keymaps, key)
  local normalized = M.normalize_key(key)

  for _, km in ipairs(keymaps) do
    local km_normalized = M.normalize_key(km.key)
    if km_normalized == normalized then
      return km.action
    end
  end

  return nil
end

---Create initial binding state
---@return table state
function M.create_binding_state()
  return {
    bindings = {},
    bufnr = nil,
  }
end

return M
