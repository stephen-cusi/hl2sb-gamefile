# hl2box — 半条命 2 沙盒（Half-Life 2 Sandbox）

在分叉 Source 引擎（[source-engine-mod](https://github.com/stephen-cusi/source-engine-mod)）上复刻原版 Garry's Mod 的游戏：以 GMod 的 Lua 生态为基准——类原版 GMod 的手感与 UI，兼容 GMod gamemode 与插件（SENT / SWEP / autorun / 注册表直写）。

> `hl2sb` 是迁移前的内部名，目录与挂载路径沿用至今；对外名称一律用 **hl2box**。

- 启动：`hl2_launcher.exe -game hl2sb -console`
- 移植状态与待办：[TODO清单.md](TODO清单.md)

## 目录导览

| 路径 | 内容 |
|---|---|
| `gamemodes/base/` | 基础 gamemode：计分、记分板、拾取通知、玩家扩展 |
| `gamemodes/sandbox/` 等 | 其余 gamemode（继承 base） |
| `lua/autorun/` | 启动注册：NPC/载具/座位表、实体 shim、spawnmenu、玩家模型、halo |
| `lua/includes/` | GMod 同名库与扩展（88 库对照状态见 TODO清单.md） |
| `lua/vgui/` `lua/derma/` | Derma 控件族与皮肤 |
| `lua/weapons/` `lua/entities/` | SWEP 与脚本实体（含 base_nextbot、base_gmodentity） |
| `resource/` `scripts/` | 本地化（GMod properties 已拷入）、武器/声音脚本 |

**资产挂载顺序**：hl2 vpk → garrysmod vpk → 本仓 loose 文件（同名覆盖）。GMod 资产自动由 vpk 补齐，一般不拷进本仓。`addons/` 为第三方插件挂载点，不入库。
