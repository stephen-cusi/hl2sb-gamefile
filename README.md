# hl2sb — Half-Life 2: Sandbox

在分叉 Source 引擎上复刻原版 Garry's Mod 的游戏内容仓：目标是以 GMod 的 Lua 生态为基准——类原版 GMod 的手感与 UI，兼容 GMod gamemode 与插件（SENT/SWEP/autorun/注册表直写）。

- **运行入口**：`D:\srceng\hl2_launcher.exe -game hl2sb -console`
- **引擎 DLL**（engine/materialsystem/…）加载自 `D:\srceng\bin`；**游戏 DLL**（client/server）加载自本仓 `bin\`
- **引擎源码仓**：`D:\project\source-engine`（分支 `box-experiment`）
- **详细工程日志**：本仓 `AGENT.md` + 引擎仓 `AGENTS.md`（踩坑/取证/部署细节都在那里，本文件只做状态总览）
- **物理枪还原参考**：`D:\srceng\gm_physgun`（反编译还原 + deps 依赖面）

## 目录导览

| 路径 | 内容 |
|---|---|
| `gamemodes/base/` | 基础 gamemode（`LUA_BASE_GAMEMODE = "base"`）：计分、记分板、拾取通知、玩家扩展、动画表 |
| `gamemodes/sandbox/` | sandbox（经 `table.inherit` 继承 base） |
| `gamemodes/deathmatch/` `campaign/` | 其余 gamemode |
| `lua/autorun/` | 启动注册：NPC/载具/座位注册表、实体 shim、挂载探测、物理枪 halo、玩家模型、spawnmenu |
| `lua/includes/modules/` | GMod 同名库（hook/concommand/timer/undo/draw/duplicator/constraint/cleanup/achievements/…） |
| `lua/vgui/` `lua/derma/` | Derma 控件族与皮肤 |
| `lua/weapons/` `lua/entities/` | SWEP 与脚本实体（含 `base_nextbot`、`base_gmodentity`） |
| `resource/` | 本地化（GMod 的 `en/zh-cn/zh-tw` properties 已拷入） |
| `scripts/` | 武器脚本、声音脚本等 |
| `addons/` | 第三方插件挂载点——**永不入库**（.gitignore 整目录排除） |

**资产挂载顺序**：hl2 vpk → garrysmod vpk → 本仓 loose 文件（hl2sb 同名覆盖）。GMod 的材质/模型/音效缺失时自动由 vpk 补齐，一般不需要把 GMod 资源拷进本仓。

## GMod 功能移植状态

图例：完成 / 部分 / 未做 / 刻意不做（含理由）。

### Lua 运行时与基础库

| 功能 | 状态 | 备注 |
|---|---|---|
| GLua 方言（`continue` `&&` `\|\` `!=` `//` 注释） | 完成 | 引擎 lparser/llex 层 |
| `file` 库全合同（封锁名单/白名单/20 方法/FSASYNC 枚举） | 完成 | `file_lib_test.lua` |
| `util` 库（CRC/SteamID64/Base64/LZMA 信封/Ray 系列/AddNetworkString/GetModelInfo） | 完成 | `util_lib_test.lua`；明确不做项见下 |
| `table.insert` 返回插入位置（GMod 语义） | 完成 | 引擎 ltablib，undo 依赖 |
| `hook` / `concommand` / `timer`（暂停/失败/RepsLeft 语义） | 完成 | |
| `undo` 系统（GMod 逐字 + 双通知修复） | 完成 | `undo_lib_test.lua` |
| `language.GetPhrase` + 中繁英 properties | 完成 | |
| `achievements`（16 个惰性桩） | 完成 | GMod 侧成就服务器不存在 |
| `SendLua` | 未做 | 现为桩 |

### Gamemode 层

| 功能 | 状态 | 备注 |
|---|---|---|
| 计分体系（`GM:DoPlayerDeath` Lua 计分、player_manager 网络化 frags/ping） | 完成 | 引擎侧零计分，对齐 GMod |
| 记分板（原版骨架 + nosteam `AvatarImage` + 麦克风图标 + `+showscoreboard`） | 完成 | |
| 玩家模型系统（扫描 models/player + 插件注册 + 文字列表菜单） | 完成 | |
| 拾取/undo 通知、`OnUndo` 单消费者 | 完成 | deathmatch `GM:OnUndo` |
| 选队 / 字体方案 | 部分 | `cl_pickteam.lua` 在；字体随场景补 |
| 聊天链（`OnPlayerChat` / `chat.AddText` 客户端半环） | 未做 | 服务端 `PlayerSay` 在 |
| `cl_deathnotice` | 未做 | 与 C++ killfeed 的共存策略待定 |

### 实体与游戏系统

| 功能 | 状态 | 备注 |
|---|---|---|
| SENT 脚本实体（`OnTakeDamage`/`TraceAttack` 伤害派发、`SetBodygroup`、`WorldSpaceAABB`） | 完成 | |
| 实体父子变换（parent-aware `SetPos`/`SetAngles`/`SetParent`，物理阴影搬运） | 完成 | |
| trace 结果合同（`Normal`=射线方向、缺省 MASK_SOLID、`ignoreworld`） | 完成 | `trace_lib_test.lua` |
| `gmod_hands` 第一人称手（DeleteOnRemove / TransmitWithParent / 死亡复活保持） | 完成 | `hands_lib_test.lua` |
| 手势同步（TE_PlayerAnimEvent：远端武器/wave/land、exclude overlay） | 完成 | |
| firstpersonbody 支撑（`SetBoneMatrix`/`RenderOverride`/`ManipulateBone*`/裁剪面；安卓 gl_ClipDistance） | 完成 | `firstpersonbody_lib_test.lua` |
| 物理枪（GMod 架构：五钩子、DT_PhysBeam、贝塞尔缎带束、骨骼抓取、E 旋转、滚轮、冻结） | 大体完成 | 对齐清单见 TODO P1 |
| halo 描边（PostDrawEffects 链 + RT 管线） | 部分 | 引擎修复 E1/E2 未落地（见 TODO） |
| NextBot（`base_nextbot` + C++ 侧） | 部分 | API 差异未全量清点 |

### UI / Derma

| 功能 | 状态 | 备注 |
|---|---|---|
| Derma 控件族（共享大元表 96+ 方法、DSlider/DNumSlider/DColorCube 逐字、DImageButton/AvatarImage） | 完成 | `derma_lib_test.lua` / `dslider_lib_test.lua` |
| spawnmenu v4（Entities/Weapons/NPCs/Vehicles 四注册表、本地化、快照缩略图、触控模式） | 完成 | |
| spawnicon 快照管线（RT + vmt 快照、视口剔除、PNG 解码兜底） | 完成 | |
| DHTML / CEF 全族 | 刻意不做 | 无浏览器层 |

## TODO 清单

### P1（下一批）

1. **物理枪对齐清单**（答疑轮已逐项反编译定案，纯机械活；施工图 = `gm_physgun/physgun_v2` 与其 README）：
   - ConVar 对齐：`physgun_teleportDistance` 250→0、`physgun_maxAngular` 5400→5000、`gm_snapangles` 45→0；新增 `physgun_DampingFactor`(0.8)、`gm_snapgrid`(0)；全部 `physgun_*` 加 `FCVAR_REPLICATED`；`maxrange/minrange` 加边界（128..32768 / 32..256）
   - 质量：`SetMass(50000)` → 45678 + savedMass 哨兵 -1 + 车辆类名判定（jeep/apc/jeep_old）
   - 冻结改走 SecondaryAttack + 0.5s 双攻击冷却门（现为 IN_ATTACK2 按下沿，无冷却）
   - 动画二态：持物 RECOIL1(204) / 空闲 174（现只有 0xB5 one-shot 回 idle）
   - 删 `Weapon_Physgun.Scanning` 循环声（参考双端零音效）
   - R 键 10ms 闸；hold 门精确化 `(buttons & 0x801) == IN_ATTACK`
2. **halo 引擎修复 E1/E2**：`IMaterial:SetString` 数值向量解析（"$color [1 1 1]" 黑屏根因）、`render.DrawScreenQuad` 内建 Push2DView；此前记录的 v3 重写（physgun_halo_rework 分支）确认已丢失，E3/E4 现状需先核对再重做
3. **cl_voice.lua 移植**：`voice_status.cpp` UpdateSpeakerStatus 四类事件 → `hook.Run("PlayerStartVoice"/"PlayerEndVoice", ply)`，保留 voice_modenable 自动开麦与 m_VoicePlayers 位；`Player:IsPlayerSpeaking` 绑定。挂点情报已齐。

### P2

4. 聊天链客户端半环：`OnPlayerChat` / `chat.AddText`
5. `SendLua` 通道（现为桩）
6. `variable_edit.lua`：引擎侧无派发，需补
7. `SetVoiceVolumeScale`（滚轮绑定缺）
8. duplicator / 工具枪生态端到端核对（`duplicator.lua` 1048 行在库，未全链验证）

### P3

9. `cl_deathnotice` 与 C++ killfeed 的共存策略
10. `player_pickup`（+use 携带）子系统（hook id 177/178，分叉完全没有）
11. 运行时探针：`gm_snapangles 0` 时 E+SHIFT 写 NaN 的实测（静态已证实的原版 bug）；2x 抓距 vs 束半距的设计意图确认
12. NextBot API 差异全量清点（`数据包/_nextbot_api_diff.py` 有底子）

### 刻意不做（勿再提）

- DHTML/CEF 族；Steam 头像（nosteam 文件方案：`data/avatars/<steamid64|name>.png`）
- `IsMounted`/`engine.GetGames`（守卫恒 false，GMod 式注册文件依赖此语义）
- `util.GetModelMeshes`、Decal 系、`PixelVisible`、undo 二进制导出（GMod 本来就没有）
- gamemode 计分放引擎侧（GMod 放 Lua 的就放 Lua，移植期会双计）

## 测试惯例

库级回归统一走 `lua_dofile <name>_lib_test.lua`（服务端）/ `lua_dofile_cl`（客户端），已有：`file` `util` `trace` `derma` `dslider` `act` `hands` `firstpersonbody` `undo` `matrix` `lnpc` 等（见 `lua/*_lib_test.lua`）。改库不改测试 = 没改完。

## 工程约定（摘要，细则见 AGENT.md / 引擎仓 AGENTS.md）

- 入库文件一律纯文本无 emoji（含注释/配置/提交信息）；行为参照写 "reference behavior / GMod does X" 式白盒注释
- 引擎公共头改动必须按 mtime 清消费目录的 .o 再编；C++ 改动先用 `source-engine/tools/hl2sb_compile_one.py` 单 TU 预编译
- 行尾：HEAD 为 CRLF 的文件用 `git -c core.autocrlf=false add` 防 blob 假 churn
- 未经验证不推送；部署 = 直接拷贝覆盖（引擎模块 → `D:\srceng\bin`，游戏 DLL → 本仓 `bin\`，PDB 同拷）
- 反编译产物归档：`D:\tmp\dec\<DLL>\<符号>.c`（+ `_index.txt`），行为结论只进 AGENTS/还原仓，不入本仓
