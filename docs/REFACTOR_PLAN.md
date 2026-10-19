# HL2SB 自研 UI 退役重构：完整执行计划（v2，2026-10-19 定稿）

本文档是可直接执行的全量计划：目标、现状盘点（含全部已知坑）、架构定案、
分阶段文件级操作清单、验收标准。执行者不需要本文档之外的对话上下文，
但必须同时读 `D:\project\AGENTS.md`（分叉事实与铁律的权威来源，遇冲突以它为准）。

## 0. 环境与资产

| 路径 | 说明 |
|---|---|
| `D:\project\source-engine` | 引擎仓（remote `fork`，分支 `box-experiment`）。构建 `./waf build --targets=client`（或 lua_shared/engine），产物在 build/ 下 |
| `D:\srceng\hl2sb` | 内容仓（remote `origin`，同分支），即游戏挂载目录，Lua 改动即改即生效 |
| 部署 | 客户端/服务端 DLL → `D:\srceng\hl2sb\bin`（+PDB 同拷，md5 核对）；lua_shared/engine → `D:\srceng\bin`（+PDB）。不留备份夹 |
| `D:\games\garrysmod\garrysmod` | GMod 本体（**只读**，逐字拷贝源）。gameinfo 已挂载其 VPK，资源不要拷进 hl2sb |
| `D:\tmp\panel_review\panel\` | GMod client.dll Panel/库绑定九轮逆向成果（panel_bindings.cpp、lib/*.cpp、decompiled/、两份 README——第十轮已收口全部占位项） |
| `D:\tmp\dec\client.dll\` | 反编译归档（981+ 文件），`_index.txt` 可 grep；Ghidra headless 流程见 AGENTS.md「GMod 反编译教程」节 |
| `D:\project\luacheck\lua_gmod.exe` | 离线 GLua 方言解释器（支持 //、!=、continue、module()） |
| `D:\project\_cmdport_probe\`、`D:\project\_spawnmenu_test\` | 离线探针/harness 目录 |
| `D:\srceng\hl2sb数据包\` | 安卓端数据包镜像，内容仓 Lua 改动后需同步 |

## 1. 铁律（执行全程有效）

1. GMod 行为必须有**原版 Lua 源码或反编译**依据，禁止按 wiki/记忆臆想。
2. 代码/配置/注释/提交信息纯文本**无 emoji**；不得出现 DLL 名+偏移、地址、FUN_ 字样、
   "反编译/decompile"措辞——行为依据一律写 "GMod does X" 式白盒描述；地址等技术取证
   只进 `D:\tmp\dec` 归档，不进仓。
3. `addons/` 目录永不 git 提交（任何 `git add -A/.` 都不许带上）。
4. 提交前查行尾：HEAD blob CRLF 而工作区 LF 的文件会出整文件假 churn，先
   `git show HEAD:file | file -` 对比再决定要不要 `-c core.autocrlf=false add`。
5. 改公共头（studio.h 级）必须按 mtime 清消费目录的 .o 再 build（AGENTS.md 有判别法）。
6. 提交信息与代码注释**无反编译痕迹**（同 2）。
7. 每阶段独立提交；引擎仓/内容仓分开；提交前 `git status` 确认没把运行时脏文件
   （cfg/、data/、serverconfig.vdf）带进去。

## 2. 保护清单（不属于本重构，严禁动/严禁混入提交）

- `engine/audio/snd_mix.cpp`、`snd_sentence_mixer.cpp`、`snd_wave_mixer.cpp`：
  **未提交的今日音频崩溃修复**（2026-10-19 上午的冷进图 dump 工作），保持原样，
  不提交、不回退、不 refactor。
- `cfg/`、`data/`、`serverconfig.vdf`：运行时脏文件，永不提交。
- `addons/`：见铁律 3。
- `D:\games\garrysmod`：只读。
- 撤销/属性/上下文菜单/persistence/hands/物理枪等已上线系统：非本重构范围，
  不顺手重构。

## 3. 现状盘点（全部已核实）

### 3.1 要退役的自研件
| 文件 | 现状 | 处置 |
|---|---|---|
| `lua/autorun/client/hl2sb_spawnmenu_gmod.lua`（1430 行） | v4 自研 spawnmenu，挂引擎 `OnSpawnMenuOpen`/`OnSpawnMenuClose` 钩子（hl2sb_spawnmenu_gmod.lua:1426） | P3 整体删除 |
| `lua/derma/hl2sb_derma.lua`、`hl2sb_derma_menus.lua`、`hl2sb_skin.lua` | 自研 derma 框架与皮肤（分叉 derma 是"形状重写"非移植） | P2 退役；`init.lua` 的垫片块逐条评估（实现优于别名的保留） |
| `lua/includes/vgui_base.lua` | 自研控件 include 表（95 个 vgui 文件，按自研框架写的控件） | 换 GMod 原版 include 表；95→93 差集逐文件评审 |
| 自研 Model 页（在 v4 内，2026-10-02 文字列表） | 玩家模型选择 | P4 换 GMod `editor_player.lua` DesktopWidget 原版 |

### 3.2 不是自研 UI、保留的资产
- 内容注册表 autorun：`hl2sb_gmod_npcs.lua`（59 条 NPC）、`hl2sb_gmod_vehicles.lua`、
  `game_hl2.lua`（stock 注册）、`lua/autorun/properties*.lua`、`lua/entities/widget_*.lua`、
  `menubar.lua`、`lua/drive/`——数据与 GMod 移植件。
- `lua/includes/modules/spawnmenu.lua`、`controlpanel.lua` 已在 modules 表（P3 逐字核对）。
- 内容注册桥接已修好：引擎 SWEP 装载器→`weapon.register`→桥→`weapons.Register`→
  `list["Weapon"]`（lua/includes/init.lua 2026-10-19 块，提交 65a9501）。
- spawnicon 快照管线（引擎侧 RT+vmt）、玩家模型扫描/player_manager、undo、properties、
  persistence、hands：保留。
- 语言包：GMod `resource/localization/{en,zh-cn,zh-tw}` 已拷入 hl2sb（VPK 不带
  properties，拷贝是必要且合法的）。

### 3.3 C++ 绑定层现状（P1 对象）
- `public/lua/vgui/{LVGUI,LISurface,LIInput,LIScheme}.cpp`（lua_shared 侧，
  2142 行）：vgui/surface/input/scheme 库绑定。
- Panel 元表走 `PanelMetaClassMgr()`（`game/client/cdll_client_int.cpp:2229`
  一带 + 客户端补丁）；另有全局 Panel 元表补丁路径（cdll_client_int.cpp:1823 注释一带）。
  **执行第一步就是把 Panel 方法的真实注册点完整摸清**（可能不止一处）。
- `lua/includes/extensions/client/panel.lua` + `panel/{animation,dragdrop,selections}.lua`
  是 GMod 原版件但**被拉黑**（cdll_client_int.cpp:1823 注释：加载后按 C 开 spawnmenu
  冻死游戏；当时 bisect 需要拉黑 render.lua 白名单里的其余文件）。GMod 原版 derma/
  spawnmenu 硬依赖这族扩展，P2 的前提是查明冻死根因。
- **GMod 反编译已证的架构事实**：GMod 的 Lua Panel 元表是**全类共享一张大表
  （约 162 方法）**，所有面板 userdata 挂同一张表；分叉按类拆元表是历次"缺方法"的
  总根因。逆向依据：`D:\tmp\panel_review\panel\decompiled\client_panel_methods_ghidra.c`
  （18 方法全文）+ 归档索引。

### 3.4 引擎既有事实（照 AGENTS.md，执行者必读）
- `module("X")` 双重加载陷阱：分叉 `luasrc_dofolder` 不写 package.loaded，同文件二次
  加载=全新模块表。hook.lua/undo.lua 用文件头重入守卫解决——凡逐字拷贝 GMod 模块
  文件都要检查这个问题。
- 枚举分歧：GMod 枚举名≠分叉（如 GMod `KEY_LSHIFT` 实为分叉 `KEY_SHIFT_LEFT`）；
  `ACT_HL2MP_*` 在分叉枚举末尾。逐字件里的裸枚举引用要过一遍映射。
- `draw.lua` 已补 `TEXT_ALIGN_*` 五行全局；`util.lua` 有 `IsMounted` 守卫（恒 false）；
  `IsSuperAdmin`、`BroadcastLua`、`SendLua` 三件套已落地。
- archived convar 的 cfg 行是"关机回写活值"；测宽必须同句柄（derma.GetTextSize /
  draw.GetFont）。
- 「引擎会回调的 Lua 方法」包壳只用 rawget ref 表（元表捕获旧 handler=无限重入）；
  基类不放空桩。
- Lua traceback 行号可 ±2 漂移；报错先查跑的哪个构建。
- `lua_dofile_cl <name>.lua` 跑客户端探针（游戏内控制台）；`lua_gmod.exe` 跑离线纯 Lua。

## 4. 架构定案（不再讨论）

1. **Panel 元表 = 单张共享大表**：所有面板 userdata 挂同一张表，方法集对齐 GMod
   （以反编译/原版 Lua 依据逐个补齐）。分叉既有已验证绑定行为不回归。
2. **derma Lua = GMod 逐字**：`lua/derma/`、`lua/vgui/` 以 GMod 本体为准逐字拷贝；
   分叉自有件仅在 GMod 无对应物时保留并标注。引擎 C++ 绑定按逆向证据补齐到逐字节
   Lua 需要的面。
3. **spawnmenu = GMod 原版系统**：`lua/spawnmenu/**` + modules 逐字；引擎
   OnSpawnMenuOpen/Close 派发已存在（+menu/-menu 是引擎 concommand），Lua 侧换成
   GMod 原版开关逻辑。
4. **内容数据源不变**：spawnmenu 各页读 `list.Get(...)`/`weapons.GetList()`
   （桥接已修好），数据 autorun 保留。
5. **玩家模型选择 = GMod editor_player.lua DesktopWidget**（主菜单桌面），数据层
   （player_manager/AddValidModel/扫描）保留。

## 5. 分阶段执行清单

### P1 C++ Panel/vgui 绑定重写（客户端 DLL，关键路径）
操作：
1. 摸清 Panel 方法注册点（public/lua/vgui + PanelMetaClassMgr + lua_shared 注册表
   + cdll_client_int 补丁），产出「现状方法清单 × GMod 目标方法清单」的 diff 表。
   GMod 侧方法名单以原版 Lua（`lua/includes/extensions/client/panel.lua`、derma
   控件实际调用面）+ 反编译归档为准；Lua 侧定义的方法不算 C++ 缺口。
2. 按共享大表架构重写元表挂接；缺失方法逐个按证据补齐。已归档语义样例（全部在
   panel_bindings.cpp/lib 有完整转写）：NULL Panel 报 "Tried to use a NULL Panel!"；
   GetParent 无父回 0 值；GetChildren 只收 +0x2AC 有效子面板、返回 1 值表；
   IsVisible 空 Panel 回 false 且仍返回 1 值；SetParent 门控+三豁免（世界面板/
   常驻面板/覆盖层根）后调引擎 SetParent；Dock 写枚举后 InvalidateLayout(false,false)
   而 DockMargin/Padding **不刷新**（GMod 二进制如此）；Remove 按第 1 参面板名查树
   标记删除；MakePopup=提到最前+鼠标键盘双开。
3. **查明 panel.lua 族冻死根因**并修复（方向：当时 derma 还是自研框架，panel.lua
   的 dragdrop/selection 依赖 GMod derma 方法面，缺方法→每帧报错→Think 泵卡死。
   P2 换原版 derma 后大概率自然解除；若仍冻死，用 hl2sb_framestats/探针二分）。
4. 构建 `./waf build --targets=client`（动 public/lua 则加 lua_shared，注意部署目录
   不同）；部署 md5 核对；不启动游戏。
验收：离线探针（lua_gmod.exe）跑通方法面断言；进图（用户验）无 C 键冻死、
derma_lib_test 全绿。

### P2 derma Lua 逐字替换（内容仓）
操作：
1. `lua/derma/`：GMod `lua/derma/{init,derma,derma_utils,...}.lua` 逐字拷入；
   分叉 `hl2sb_derma*.lua` 退役；init.lua 的垫片块（比别名聪明的实现）逐条评估。
2. `lua/vgui/`：以 GMod 93 文件为准逐字拷贝；分叉 95 文件差集逐个评审（GMod 有
   同名原版→替换；GMod 无此控件→评估去留并标注）。分叉已逐字移植过的
   （DSlider/DNumSlider/DColorCube/DNumberScratch，2026-10-02）核对版本即可。
3. `lua/includes/vgui_base.lua` 换 GMod 原版 include 表（GMod 是 54 个 include 的
   原版文件）。注意 cdll_client_int.cpp:1833 注释：引擎对 init/util/vgui_base 用
   单文件 dofile 防二次扫描——换文件不影响该机制。
4. 解除 `extensions/client/panel.lua` 族拉黑（P1 结论落地后）。
5. 枚举：GMod `sh_enumerations.lua` 所需子集激活（分叉副本在
   `lua/includes/modules/gmod_compatibility/sh_enumerations.lua`，目前入口
   `gmod_compatibility.lua` 因 `GMOD_COMPATIBILITY=false` 惰性——把枚举与无害
   部分单独拉活，不激活整个 sh_init（它 require bitwise/gamemodes 等未移植模块））。
   枚举名映射按 AGENTS.md 分歧表。
6. 分叉 derma 探针 `derma_lib_test.lua` 按 GMod 语义重写断言。
验收：`lua_dofile_cl derma_lib_test.lua` 全绿；逐字件与 GMod 本体 cmp 抽查一致；
分叉自有 shim（DTextEntry SetValue 等）在原版件落地后删除冗余。

### P3 spawnmenu 原版照搬（内容仓）
操作：
1. 拷 GMod `lua/spawnmenu/**`（spawnmenu.lua 模块、creationmenu、toolmenu、
   contextmenu、controlpanel、controls）逐字入 `lua/spawnmenu/`；
   `lua/includes/modules/spawnmenu.lua`、`controlpanel.lua` 与 GMod 本体逐字核对
   （已在 modules 表，覆盖即可）。
2. 删 `lua/autorun/client/hl2sb_spawnmenu_gmod.lua`；`OnSpawnMenuOpen/Close` 钩子
   改挂 GMod 原版 spawnmenu 开关逻辑（GMod 的 spawnmenu.lua 模块怎么消费这两个
   引擎钩子就怎么挂）。
3. 内容页数据源已是 `list.Get("SpawnableEntities"/"NPC"/"Vehicles")` +
   `weapons.GetList()`（桥接已修）——原版 creationmenu 的读法一致；NPC/载具/
   实体注册 autorun 保留。
4. SpawnIcon 缩略图：GMod 的 spawnicon 走引擎快照，分叉已有等价管线
   （render.CreateNamedRenderTarget + Snapshot + materials/spawnicon vmt，
   见 AGENTS.md 玩家模型系统节）；逐字件若直调引擎接口差异，垫在引擎绑定侧而非
   改逐字件。
5. 语言 token：GMod token 原形已在三语 properties；缺 token 按 GMod 本体补。
6. 工具菜单页：GMod toolmenu 的工具注册（`list.Set`/toolmode）分叉还没有工具——
   页面结构照搬、内容空可接受，别造自研工具。
验收：进图 smoke（见 P5）；`/d/project/_spawnmenu_test/reg_test.lua` 回归。

### P4 自研菜单替换（内容仓）
1. 玩家模型：GMod `gamemodes/sandbox/gamemode/editor_player.lua` DesktopWidget 原版
   接线（`list.Set("DesktopWindows","PlayerEditor",...)` + 23 个
   PlayerOptionsAnimations 已有骨架，对照原版补差）；入口走 GMod 主菜单桌面/
   约定方式，不开自研入口；自研 Model 页随 v4 删除（P3 已删）。
2. `menubar.lua`/通知等已是 GMod 件：逐字核对。
3. 其余自研弹窗（如有）逐个对照 GMod 原版处理，没有原版对应物的列清单报给用户。
验收：玩家模型编辑器从 GMod 入口可开、换模即时生效（cl_playermodel 路径链已有）。

### P5 回归
- 离线：`derma_lib_test.lua`（重写版）、`trace_lib_test.lua`、`undo_lib_test.lua`、
  `file/util_lib_test.lua`、`_spawnmenu_test/reg_test.lua` 全绿。
- 进图 smoke（用户执行）：C 开原版 spawnmenu；各页内容正确（Entities/Weapons/
  NPCs/Vehicles/Props）；生成 SWEP（进背包）/SENT/prop/NPC/载具；右键属性菜单全项；
  持久化 make persistent + 重进；玩家模型编辑器换模；工具页结构；无控制台刷屏
  （重点盯 panel.lua 族与 derma 加载）。
- 数据包镜像同步：内容仓改动的 Lua 拷到 `D:\srceng\hl2sb数据包\` 对应路径。

## 6. 已知坑速查（历史事故，勿重蹈）

- 拉黑文件重新启用必须单独一轮验证（panel.lua 族曾把 C 键冻死）。
- 引擎 Lua 状态每次换图重建：全局表/模块注册要耐受重建（重入守卫模式）。
- `luasrc_dofolder` 不递归、不写 package.loaded。
- GMod 的 `vgui.Register/RegisterTable/GetControlTable` 是 C++ 绑定（分叉
  lua_registry 已有可移植实现，见 panel/lib/lua_registry.cpp，带测试）。
- GMod 面板 userdata 前 8 字节=Panel*、+8 类型标记（逆向第九轮）；分叉自定布局
  亦可，但 PushPanel/CheckPanel 必须全库一致。
- `file.Write` 缺省落 DATA；写 materials/ 等必须显式 "GAME"。
- derma 事件派发器（DoClick 等）是 Lua 侧引发（dlabel.lua），别加 C++ 双发。
- `IsMounted` 恒 false 守卫必须保留，否则 GMod 式注册文件整文件失败。
- 中文注释行尾保持 ASCII（C1018 教训）；往文件插内容用 Read+Edit，别用 heredoc。

## 7. 汇报格式

每阶段收尾汇报：改动文件清单（新增/删除/修改分列）、逐字件与 GMod 的 cmp 差异
（应为 0 或逐条解释）、构建/部署 md5、探针与 smoke 结果、遗留风险与下一阶段依赖。
