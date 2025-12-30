--- types.lua - ハンドラー型定義

--- @class K8sCallbacks
--- @field render_footer fun(view_type: string, kind?: string): nil レンダリング: フッター更新
--- @field fetch_and_render fun(kind: string, namespace: string, opts?: table): nil レンダリング: リソース取得・描画
--- @field render_filtered_resources fun(): nil レンダリング: フィルター適用後の再描画
--- @field handle_refresh fun(): nil アクション: リフレッシュ
--- @field handle_port_forward_list fun(): nil アクション: ポートフォワードリスト表示
--- @field setup_keymaps_for_window fun(win: K8sWindow): nil セットアップ: ウィンドウにキーマップ設定
--- @field get_footer_keymaps fun(view_type: string, kind?: string): table[] 取得: フッター用キーマップ定義

--- @class K8sHandlers
--- @field close fun(): nil UIを閉じる
--- @field handle_back fun(): nil 前のビューに戻る
--- @field handle_describe fun(): nil リソース詳細表示
--- @field handle_refresh fun(): nil リフレッシュ
--- @field handle_filter fun(): nil フィルター入力
--- @field handle_delete fun(): nil リソース削除
--- @field handle_logs fun(): nil ログ表示
--- @field handle_logs_previous fun(): nil 前回ログ表示
--- @field handle_exec fun(): nil Pod exec
--- @field handle_scale fun(): nil スケール変更
--- @field handle_restart fun(): nil リスタート
--- @field handle_port_forward fun(): nil ポートフォワード開始
--- @field handle_port_forward_list fun(): nil ポートフォワードリスト
--- @field handle_stop_port_forward fun(): nil ポートフォワード停止
--- @field handle_resource_menu fun(): nil リソースメニュー
--- @field handle_context_menu fun(): nil コンテキストメニュー
--- @field handle_namespace_menu fun(): nil ネームスペースメニュー
--- @field handle_toggle_secret fun(): nil シークレット表示切替
--- @field handle_help fun(): nil ヘルプ表示

--- Handler callback requirements documentation
--- Each handler function documents which callbacks it uses
---
--- list_handler:
---   handle_back: render_footer, fetch_and_render
---   handle_refresh: fetch_and_render
---   handle_filter: render_filtered_resources
---   handle_delete: handle_refresh
---   handle_scale: handle_refresh
---   handle_restart: handle_refresh
---   handle_toggle_secret: render_filtered_resources
---   render_filtered_resources: (none - internal function)
---
--- describe_handler:
---   handle_describe: setup_keymaps_for_window, get_footer_keymaps
---   handle_logs: (none)
---   handle_logs_previous: (none)
---   handle_exec: (none)
---
--- port_forward_handler:
---   handle_port_forward: (none)
---   handle_port_forward_list: setup_keymaps_for_window, render_footer
---   handle_stop_port_forward: handle_port_forward_list
---
--- menu_handler:
---   handle_resource_menu: setup_keymaps_for_window, get_footer_keymaps, fetch_and_render
---   handle_context_menu: handle_refresh
---   handle_namespace_menu: fetch_and_render
---   handle_help: setup_keymaps_for_window, render_footer

local M = {}

---Validate that callbacks object has required fields
---@param callbacks table
---@param required_fields string[]
---@return boolean valid
---@return string|nil missing_field
function M.validate_callbacks(callbacks, required_fields)
  for _, field in ipairs(required_fields) do
    if callbacks[field] == nil then
      return false, field
    end
  end
  return true, nil
end

---Get callback requirements for a handler
---@param handler_name string
---@return string[]
function M.get_callback_requirements(handler_name)
  local requirements = {
    -- list_handler
    handle_back = { "render_footer", "fetch_and_render" },
    handle_refresh = { "fetch_and_render" },
    handle_filter = { "render_filtered_resources" },
    handle_delete = { "handle_refresh" },
    handle_scale = { "handle_refresh" },
    handle_restart = { "handle_refresh" },
    handle_toggle_secret = { "render_filtered_resources" },

    -- describe_handler
    handle_describe = { "setup_keymaps_for_window", "get_footer_keymaps" },
    handle_logs = {},
    handle_logs_previous = {},
    handle_exec = {},

    -- port_forward_handler
    handle_port_forward = {},
    handle_port_forward_list = { "setup_keymaps_for_window", "render_footer" },
    handle_stop_port_forward = { "handle_port_forward_list" },

    -- menu_handler
    handle_resource_menu = { "setup_keymaps_for_window", "get_footer_keymaps", "fetch_and_render" },
    handle_context_menu = { "handle_refresh" },
    handle_namespace_menu = { "fetch_and_render" },
    handle_help = { "setup_keymaps_for_window", "render_footer" },
  }

  return requirements[handler_name] or {}
end

return M
