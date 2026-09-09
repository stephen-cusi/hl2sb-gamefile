# GMod Lua 函数移植计划清单 — HL2SB

> 目的：把 GMod 内置 Lua 的大部分库移植到 HL2SB，但**用 HL2SB 的 Lua 风格**
> （Source Lua 5.1、`hook.add/call`、`surface.*` 直接绑定、无 BOM 的 UTF-8），
> 或在需要时**扩展 HL2SB 的原生绑定**，而不是硬贴 GMod 的 LuaJIT 写法。
>
> 阅读本清单前先读仓库 `AGENTS.md` 第 5.4 节（Lua SDK 事实）：
> `lua/autorun/` **不会被加载**，路径必须是 `lua/includes/{modules,extensions}`、
> `lua/game/{shared,client,server}`。
>
> 清单中每一项标了：**现状** / **落点** / **依赖** / **优先级**。

---

## 0. 总览：两边环境对照

| 维度 | GMod | HL2SB |
|---|---|---|
| Lua 版本 | LuaJIT | Source Lua 5.1（`LUA_VERSION_NUM 501`） |
| 加载 | `autorun` + `includes` | `includes` + `game`（无 autorun） |
| 模块函数 | `hook.Run` / `CreateConVar` / `math.Clamp` | 只到 `hook.add/call`，无这两个 |
| 绘制 | `surface.*` + `draw.*` | `surface.*`（`LISurface.cpp` 已补全） |
| 根表 | `module("x")` 全局库 | 同样 `module("x")`，天然兼容 |
| 编码 | 随意 | **必须 UTF-8 无 BOM** |

关键结论：HL2SB 的模块机制和 GMod 一样是 `module("name")` + 全局 `name.*`，
所以**大部分 GMod 纯 Lua 模块可以「照搬」**，只要 ① 依赖的 `surface`/实体方法绑定存在，
② 把少数 GMod 专属全局函数 （`CurTime`/`scrw`/`math.Clamp` 等）用 HL2SB 等效实现或补绑定。

---

## 1. 直接移植（纯 Lua，几乎零改动，高价值、低风险）

这些模块**只依赖 surface/基础库**，HL2SB 已具备，拷过去改个头部注释即可。

| 模块 | GMod 函数 | HL2SB 落点 | 依赖 | 备注 |
|---|---|---|---|---|
| `draw` | GetFontHeight / SimpleText / SimpleTextOutlined / DrawText / RoundedBox / RoundedBoxEx / WordBox / Text / TextShadow / TexturedQuad / NoTexture | `includes/modules/draw.lua` | `surface.GetTextureID` ⚠️ | 需确认 LISurface 有 `GetTextureID`；颜色用 `color.r` 表结构，HL2SB 的 `Color` userdata 支持 `.r/.g/.b/.a` ✅ |
| `utf8` | char / codes / codepoint / len / offset / force / GetChar / sub | `includes/modules/utf8.lua` | 纯 Lua? 否，GMod 是 LuaJIT 原生 utf8 | ⚠️ 见 §4：HL2SB 需自写或仅取 len/sub |
| `string` 扩展 | Explode / Split / Implode / Trim / Left / Right / Replace / StartsWith / EndsWith / NiceTime / FromColor / ToColor / Comma / NiceName… | `includes/extensions/string.lua` | 纯 Lua ✅ | **最容易，第一批做** |
| `table` 扩展 | Pack / Empty / IsEmpty / Copy / Merge / Add / Count / Random / Shuffle / IsSequential / ToString / Reverse / ForEach / GetKeys / Flip / move… | `includes/extensions/table.lua`（现只有 copy/hasvalue/inherit/merge/print/tokeyvalues） | 纯 Lua ✅ | **扩展现有文件**，别覆盖已有 6 个 |
| `math` 扩展 | Clamp / Distance / Rand / Round / Approach / Sign / NormalizeAngle / IsNearlyEqual / Remap / SnapTo / TimeFraction / EaseInOut / CubicBezier… | `includes/extensions/math.lua` | 纯 Lua ✅ | 依赖 `math.floor` 等标准库 |
| `concommand` 对齐 | GMod: GetTable/Add/Remove/Run/AutoComplete | `includes/modules/concommand.lua`（现有 Create/Dispatch/Remove） | 已有 ConCommand 绑定 | **补齐 `Run`/`GetTable`**，风格换 `concommand.Create` |

## 2. 半移植（需要少量 HL2SB 风格适配，中等价值）

这些模块逻辑照搬，但函数签名或返回值需贴合 HL2SB 的绑定。

| 模块 | 需适配点 | 落点 | 依赖 |
|---|---|---|---|
| `hook` 对齐 | GMod 用 `hook.Run` / `hook.GetTable` / `hook.Call`；HL2SB 只有 `add/call/gethooks/remove` | `includes/modules/hook.lua` | 纯 Lua + C++ `BEGIN_LUA_CALL_HOOK` 调 `hook.call`。**建议加 `hook.Run`（= `call` 无 gamemode 参数转发）** 作别名，兼容大量 GMod 脚本 |
| `killicon` | GMod 用 `AddFont/Add/AddTexCoord/AddAlias/Exists/GetSize/Render/Draw` | `includes/modules/killicon.lua` | 需引擎绑定：读字体字形 + 材质。HL2SB 已有 `hl2sb_deathnotice.lua` 用 surface 硬编码 `KILLICON_GLYPH` | 可做「HL2SB 版 killicon 库」，内部走 `surface.GetCharacterWidth` + 材质，**对外暴露 GMod 同款 `killicon.Render`**，让死亡通知脚本也能用 |
| `team` | `SetUp/GetAllTeams/GetName/GetColor/SetColor/GetPlayers/NumPlayers/Valid` | `includes/modules/team.lua` | 需读玩家团队/队伍颜色。HL2SB 是 HL2MP 队伍（`g_PR` 层）。**纯 Lua 能返回硬编码队伍表**，色值读游戏 `TeamColor` | 半成品可行 |
| `gamemode` 对齐 | GMod: Register/Get/Call；HL2SB: 同 plus `_GAMEMODE` 概念 | `includes/modules/gamemode.lua` | 已有 | 补 `_GAMEMODE` 语义对齐即可 |
| `list` | Get/GetTable/GetForEdit/Add/Contains/Set/RemoveEntry/HasEntry/GetEntry | `includes/modules/list.lua` | 纯 Lua（注册表）✅ | 关键依赖是「实体/武器注册表」填入，属半成品 |
| `weapons`/`scripted_ents` | Register/Get/GetList/GetStored/Alias/IsBasedOn | `includes/modules/weapons.lua` / `scripted_ents.lua` | 需 HL2SB 实体注册系统对接 | 中/高价值，但要看 HL2SB 的 C++ 注册接口是否暴露到 Lua |
| `player_manager` | RegisterClass/SetPlayerClass/GetPlayerClasses/RunClass/LoadClass | `includes/modules/player_manager.lua` | 对接 HL2SB 玩家模型系统（你已有 `hl2sb_playermodel.lua`） | 与现有 playermodel 功能融合 |
| `baseclass` | Get/Set | `includes/modules/baseclass.lua` | 纯 Lua ✅ | 配合 `table.inherit` |

## 3. 重移植（需要新增 C++ 绑定，高风险，按需）

这些核心靠引擎绑定，HL2SB **必须有对应 C++ 函数**才能跑，纯 Lua 做不了。

| 模块 | 缺什么 | 建议 |
|---|---|---|
| `net` | 全套 `net.*`（Write/Read/Start/Send/Receive/ReadHeader…）+ `util.NetworkIDToString` + `MAX_EDICT_BITS` 常量 | HL2SB 完全无 net 系统。**这是最大工程**。可行方案：在引擎加一套 Lua `net.*` 绑定（基于 `bitbuf`/`ISendMessage`），再移植 GMod `extensions/net.lua`、`modules/usermessage.lua`。价值大（网络刷新、刷屏、同步），但需谨慎 |
| `cvars` 顶层 | `CreateConVar` / `GetConVar` / `GetConVarNumber` / `GetConVarString`（全局） | HL2SB 只有 `ConVar` userdata + `cvar` 模块（回调）。**建议加全局 `CreateConVar`/`GetConVar*`**，GMod 脚本最常用。优先做 |
| `ents`/`entity` 扩展 | `ents.FindByClass` / `ents.Iterator`/`ents.GetAll` / `ents.Create` | HL2SB 有 `luaopen_gEntList`、`luaopen_UTIL`，但缺 `ents.*` 查找族 | 补 `ents.FindByClass/FindByName/GetAll` |
| `player` 扩展 | `player.GetAll/GetBySteamID/GetByUniqueID/Iterator` | HL2SB 有 `engine.GetLocalPlayer`、`player.Iterator`?（`entity.lua` 有 `getentities`） | 补 `player.GetAll` = 遍历 + `:IsPlayer()` |
| `halo` / `effects` | `halo.Add/Render`、`effects.Register/Create` | HL2SB 无 | 低价值，pending |
| `numpad` / `drive` / `properties` | 绑定输入/物理 | 纯 Lua 依赖 `input.*`/实体绑定 | pending |
| `matproxy` | `matproxy.Add` | **HL2SB 是 Lua5.1 无 LuaJIT，GMod 的 matproxy 是 C++ 层回调**。你已用 C++ `CPlayerColorProxy` 实现过同类。**此模块不建议照搬**，按需在 C++ 加 | P3 |

## 4. 哪些**不该**照搬（会坏）

| 项 | 原因 |
|---|---|
| `matproxy.lua` | GMod 的 matproxy 是引擎 C++ 注册的 proxy 回调 + LuaJIT；HL2SB 材质代理需 C++ 实现，不能靠 lua。你已有 `CPlayerColorProxy` 先例 |
| `usermessage.lua` | 依赖 `usermessage.Hook` 绑定，HL2SB 无；配套 `SendUserMessage` |
| `utf8.lua` 全量 | GMod 的 `utf8.*` 是 LuaJIT 原生 lua 插件；HL2SB Lua5.1 无该库，需注源码或只实现 `len/sub` |
| `spawnmenu`/`menubar`/`widget`/`properties` | 依赖 Derma（`vgui` 控件树），HL2SB 的 vgui 绑定较弱（`lEditablePanel`/`lPanel`），先不做 |
| `undo`/`duplicator`/`saverestore`/`presets` | 依赖 `file` 系统 + Derma UI + 实体序列化，工程量大且与 HL2SB 机制不符 |
| `http` | 依赖网络层 + JSON；HL2SB 无此绑定 |

---

## 5. 执行清单（真实状态，勾选 = 已完成并验证）

> 状态核对时间点：GMod 拾取 HUD 完成后。
> 清单里的文件路径均按 HL2SB `D:\srceng\hl2sb\lua` 相对路径写。
> `[x]`=已在游戏验证 / `[~]`=已写未验证 / `[ ]`=未动。

### P0（先补全局函数，GMod 脚本兼容的大门）
- [ ] `includes/extensions/string.lua` — Explode/Split/Trim/Left/Right/Replace/StartsWith/EndsWith（**未做**）
- [x] `includes/extensions/math.lua` — Clamp/Round/Sign/Approach/Remap/EaseInOut/IsNearlyEqual（**已做**）
- [ ] `includes/extensions/table.lua` — 扩充 Pack/Empty/IsEmpty/Copy/Count/Random/IsSequential/Reverse（**当前只有 copy/hasvalue/inherit/merge/print/tokeyvalues，未扩充**）
- [ ] 引擎加全局 `CreateConVar`/`GetConVar`/`GetConVarNumber`/`GetConVarString`（**未做，需 C++**）
- [x] `hook.lua` 加 `hook.Run` 别名（**已做，离线测试通过**）

### P1（HUD/UI 常用）
- [x] `includes/modules/draw.lua` — GMod 版 draw 库（**已做，游戏内验证：SimpleText/RoundedBox/GetFontHeight 正常**；RoundedBox 保持直角）
- [ ] `includes/modules/list.lua`（**未做**）
- [ ] `includes/modules/team.lua` — 半成品，返回硬编码队伍（**未做**）
- [x] `includes/modules/killicon.lua` 相关 — 拾取武器/弹药 icon 用字体字形（**部分，见下**）
- [x] GMod 拾取 HUD（`game/client/hl2sb_cl_hudpickup.lua`）— 拾取条 + 弹药合并 + 列表居中 + 屏蔽原版拾取图标（**已做，游戏内验证**）

### P2（实体/网络）
- [ ] `ents.FindByClass/FindByName/GetAll`（**未做**）
- [ ] `player.GetAll` / `player.Iterator`（**未做**）
- [ ] `net.*`（引擎绑定 + 移植 `extensions/net.lua`）——**大工程，单独一轮**
- [ ] `usermessage.*`

### P3（按需）
- [ ] `player_manager` 对接 playermodel
- [ ] `scripted_ents`/`weapons` 注册对接
- [ ] `gamemode` 语义对齐 `_GAMEMODE`

---

## 5.1 已完成里程碑（可回看）

| 完成项 | 落点 | 验证 |
|---|---|---|
| `surface.SetFont(name)` 绑定（GMod 字符串字体名→hFont） | `public/lua/vgui/LISurface.cpp` | 编译 + 部署 + 提交 `23d472d6` |
| `includes/extensions/math.lua` | `hl2sb/lua/includes/extensions/math.lua` | Lua5.1 离线测试通过 |
| `includes/modules/draw.lua`（GMod 版，含 Color 分量坑修复） | `hl2sb/lua/includes/modules/draw.lua` | 游戏内验证（userdata Color mock） |
| `hook.Run`（GMod 兼容） | `hl2sb/lua/includes/modules/hook.lua` | 离线测试通过 |
| **GMod 拾取 HUD**（服务端 item_pickup 事件 → Lua 拾取条） | `game/client/hl2sb_cl_hudpickup.lua` + 引擎侧 `item_world.cpp`/`item_ammo.cpp`/`basecombatcharacter.cpp`/`hl2mp_player.cpp`/`hud_killfeed.cpp`/`hud_weaponselection.cpp` | 游戏内验证（弹药数量/合并/居中/屏蔽原版图标） |

---

## 5.2 引擎缺失功能（需 C++ 绑定，加到移植计划）

这些 GMod 脚本常用、但 HL2SB 引擎**当前没有**的绑定。按"缺什么 → 建议"列，方便后续逐个补。

| 缺失 | 说明 / 建议 | 优先级 |
|---|---|---|
| `ents.GetAll` / `ents.FindByClass` / `ents.FindByName` | 遍历世界实体。HL2SB 有 `luaopen_gEntList`(server)但无这些方法 | **P2，高** |
| `player.GetAll` / `player.Iterator` | 遍历玩家。需在客户端/服务端绑定 player 列表迭代 | **P2，高** |
| 全局 `CreateConVar` / `GetConVar` / `GetConVarNumber` / `GetConVarString` | GMod 脚本声明/读 cvar 的入口。HL2SB 只有 `ConVar` userdata + `cvar` 模块(回调) | **P0，高** |
| `surface.GetTextureID` / `surface.SetTexture` / `DrawTexturedRectRotated` / `DrawRect` | GMod draw 库原生用；HL2SB 用 `DrawSetTexture`/`DrawTexturedSubRect`/`DrawFilledRect` 替代。**若要让 GMod 脚本原样跑 draw 库，需补这些别名** | 中 |
| `util.NetworkIDToString` / `net.*`(Read/Write/Start/Send) | HL2SB 无 net 系统。最大工程，单独一轮 | **P2，大** |
| `usermessage.Hook` / `SendUserMessage` | GMod 的 usermessage Lua 绑定。HL2SB 无 | 低 |
| `IsValid`(全局) / `isfunction` / `istable` / `isstring` / `isentity` | GMod 全局类型谓词。HL2SB 只有 `util.IsValid`、实体 metatable 上 | **P0，高** |
| `LocalPlayer()` / `CurTime()` / `ScrW()` / `ScrH()` | GMod 全局。HL2SB 用 `engine.GetLocalPlayer`/`gpGlobals.curtime`/`surface.GetScreenSize`。**若移植 GMod 脚本需补别名** | 中 |
| `entity`/`weapon` 实体方法 `Name` / `GetClass` / `Team` / `Nick` / `GetColor` | HL2SB 实体绑定只有 `IsPlayer`(此前核实)。GMod 脚本大量用这些 | 中 |
| `killicon` 库(Add/AddFont/GetSize/Render) | HL2SB 无。killfeed/拾取 icon 现用字体字形硬编码 `KILLICON_GLYPH` 替代 | 中 |
| `team.GetColor` / `list.Get` | HL2SB 无 team/list 库(纯 Lua 可做部分) | 中 |

### 关键坑备忘（已记录到 AGENTS.md 5.4）
- **`Color` 分量取值**：HL2SB `Color` 是 userdata，`.r/.g/.b/.a` 是**方法函数**不是字段。
  `col.r` → 函数；必须 `col:r()/col:g()/col:b()/col:a()`。照搬 GMod 脚本必炸。
- **`module()` 环境**：Lua5.1 默认无 seeall，module 体内的裸全局会变 nil。
  用 `module("name", package.seeall)` 并尽量在 module 前捕获全局。
- **`HudElementShouldDraw`**：HL2SB 引擎已有此钩子（≈ GMod HUDShouldDraw），可隐藏任意 HUD 元素。
  注意 `DECLARE_HUDELEMENT` 的元素名 = 类名（带 `CHud` 前缀），如 `CHudHistoryResource`。
- **`gui/cornerX` 材质**：HL2SB 能正确着色渲染（$vertexcolor 可用），但拾取 HUD 选择保留直角。

---

## 6. 风格约定（HL2SB 版）

- 每个新库用 `module("name")`，与 GMod 一致 → 直接兼容。
- 头部改成 HL2SB/Source 5.1 注释（去 LuaJIT 特有注释）。
- 只用 HL2SB 已验证的原语：`surface.*`、`hook.add/call`、`Color`、`gpGlobals.curtime`、
  `concommand.Create`、`table.copy`、`math.*`（标准）。
- 新增绑定**确认进了 .vpc**（`client_lua.vpc` / `game/shared` 对应 target），
  **新 .cpp 必须列进 vpc 或塞进已编译 .cpp**（AGENTS.md 现有坑）。
- 编码一律 UTF-8 无 BOM；改完跑 `python tools/check_lua_utf8.py`。
- 改完用 `lua_dofile_cl` 热重载验证，看日志 print 标记确认加载（`lua/game/client`）。

---

## 7. 参考文件

- GMod 源：`D:\games\garrysmod\garrysmod\lua\includes\{modules,extensions}\*.lua`
- GMod API 文档：`D:\gmod_wiki_docs\libraries\*.md`、`...\globals\`、`...\extensions\`
- HL2SB 现有：`D:\srceng\hl2sb\lua\includes\{modules,extensions}\`
- HL2SB 引擎绑定注册表：`source-engine\game\shared\lua\lsrcinit.cpp`（决定哪些函数纯 Lua 可实现）
