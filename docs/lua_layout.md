# Lua 目录职责与 GMod 迁移待办

最近核对日期：2026-10-24，参考实际安装的 Steam GMod。文件存在或名称相同，不代表原生 API 已完整实现，也不代表已经通过游戏内验证。

## 运行时职责

| 位置 | 职责 |
| --- | --- |
| `lua/includes/init.lua` | 分叉启动入口：加载原版辅助库、Derma 和明确列出的兼容层 |
| `lua/includes/modules/`、`lua/includes/extensions/` | 公共库，包含现有的原生 API 适配 |
| `lua/hl2sb/compat/` | 原生接口别名、字体、实体与网络桥接、启动设置和兼容命令 |
| `lua/hl2sb/compat/registrations/` | 已适配的 NPC、座椅和载具注册 |
| `lua/autorun/hl2sb_compat.lua` | 双端自动加载入口，随后加载仅服务端使用的旧命令兼容 |
| `lua/autorun/client/hl2sb_compat.lua` | 录制命令和 Lua 错误提示适配 |
| `lua/game/client/font.lua` | 旧字体适配的薄入口，保持原有的原生加载阶段 |
| `gamemodes/base/gamemode/` | 原版 base 规则、玩家类、计分板、语音、拾取和死亡通知 |
| `gamemodes/sandbox/gamemode/` | 原版 Sandbox 菜单、命令、通知和玩家规则 |
| `gamemodes/<name>/entities/` | 原版实体、效果和武器目录，原生加载器现已支持 |
| `lua/tests/`、`lua/utilities/` | 手动诊断脚本，正常启动时不自动加载 |
| `lua/gameui/`、`lua/menu/` | 现有菜单域界面，包括由原生层加载的准星编辑器 |

公共库仍按原生依赖顺序先于 includes/init.lua 加载。原先在 autorun 阶段运行的兼容代码仍保留该阶段，不提前到原版公共库之前。字体适配也保留原来的 game/client 阶段。本轮清理没有改写原版 GMod 文件。

## 已移出自动加载的旧实现

下表中的路径均相对于 `lua/`。

| 旧文件 | 移除原因及当前负责方 |
| --- | --- |
| `autorun/server/hl2sb_falldamage.lua` | 每次进图将 mp_falldamage 重置为 0，覆盖已有配置；现在由 base 的 GetFallDamage 读取实际配置 |
| `autorun/server/hl2sb_player_color.lua` | 重复通过 PlayerSpawn 写玩家颜色；现在由原版 Sandbox 玩家类初始化颜色 |
| `autorun/client/hl2sb_displayname.lua` | 为旧击杀通知和撤销适配提供的全局函数，已无调用方 |
| `autorun/client/hl2sb_crosshair_setup.lua` | 空入口；原生菜单启动流程已加载 menu/crosshair_setup.lua |
| `autorun/server/hl2sb_gm_binds.lua` | 帮助和队伍命令已有原生实现；仅在 compat/server_commands.lua 保留旧 gm_showspawns 命令 |
| `hl2sb/compat/notification.lua` | 重复提供过滤器空操作、枚举，并尝试修改 GM；原版 Sandbox 的 cl_notice.lua 已负责 AddNotify |
| `autorun/sbrust_binary_modules.lua` | 自动 require 示例模块 my_first_binary_module；现移至 tests/sbrust_binary_modules.lua，仅供手动运行 |

旧物理枪 halo 自动脚本因与原版 Sandbox 渲染冲突，已在上一轮删除，不重复计入本轮成果。旧建造菜单、被禁用的 Experiment 启动入口和根目录诊断脚本已在 2026-10-23 处理。

## 已迁移及继续保留的适配

实体兼容、NPC/座椅/载具注册、玩家载具接口别名、录制命令、Lua 错误提示和旧字体适配已迁入兼容目录。文件正文与清理前快照逐字一致。二进制模块示例移至 tests，正文同样未改。两个 autorun 入口保持这些组件原有的相对加载顺序。

资源挂载与探测、game_hl2 注册、实体属性注册和 utilities_menu 继续运行，因为它们仍提供实际内容或设置。draw、language、gmod_surface、gmod_globals、gmod_compat 等适配公共库，以及实体兼容代码，仍有真实依赖。不能仅凭名称或旧注释删除，必须先补齐对应原生实现并逐项验证接口契约。

Gamemode 迁移已支持原版 entities 目录，并将已支持的类和效果迁入。工具枪及其工具脚本、适配后的基础实体和 NextBot 类暂留 lua/，因为虚拟 LUA 路径查询或引擎桥接仍依赖这些位置，不能当作重复实现直接删除。deathmatch 和 campaign 仍是可选游戏模式。

## 剩余工作与限制

- 部分注册和公共库仍与当前安装的 GMod 不同。本轮没有将其标为原版逐字一致或行为完全对齐。
- 队友碰撞与避让的原生消费者、SetLOD、原版 .gms 存档链和真实语音音量混音尚未完成。仅保存 Lua 字段或提供空操作绑定不算实现。
- CEF/HTML/JavaScript 和多数 Steam 服务不在当前支持范围。相应依赖被替代前，保留现有菜单域界面。
- 字体容器及实体网络、控件适配仍属于必要兼容；移除这些包装前，需要验证对应原生接口契约。

清理前 Lua/gamemode 快照、精确移动与删除清单、按同路径比较的原版文件清单，以及离线检查记录，均保存在 `D:/tmp/hl2sb_lua_cleanup_20261024/`。同路径清单区分一致、不同和分叉独有；迁移过位置的文件可能被归入分叉独有，存在差异也不等于存在 bug。

本轮未修改插件或运行数据，未启动游戏，游戏内验证仍待完成。
