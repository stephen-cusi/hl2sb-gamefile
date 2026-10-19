# P2 / P3 执行清单（derma 与 spawnmenu 换 GMod 原版）

本文件是 `REFACTOR_PLAN.md` 的 P2/P3 细化版，记录已定案的方案与逐文件操作，
使下一轮可以直接机械执行。方案选择与依赖审计见文末「决策记录」。

原版来源（只读）：`D:\games\garrysmod\garrysmod`

```
lua\derma\*.lua                                    7 个文件
lua\vgui\*.lua                                    93 个文件
lua\skins\default.lua                              1 个文件
lua\includes\modules\{spawnmenu,controlpanel}.lua  2 个文件
gamemodes\sandbox\gamemode\spawnmenu\**           33 个文件
```

## 1. 桥接层（方案 B，唯一保留的分叉件）

新建 `lua/derma/hl2sb_bridge.lua`，从现行 `lua/derma/hl2sb_derma.lua` 中只保留
注册与创建管线，删掉自研 derma 外观/控件/菜单部分：

| 保留 | 作用 |
|---|---|
| `vgui.Create`（含 `vgui.CreateX` 别名） | 类名 -> 控件表 -> 引擎基类面板 |
| `vgui.Register` / `vgui.RegisterTable` / `vgui.CreateFromTable` | 控件表注册与继承链 |
| `derma.DefineControl` / `derma.DefinePanel` | 对齐 GMod 的注册入口 |
| `BaseClass` 代理（`attachBaseClass`） | `self.BaseClass:Method()` 惯用法 |
| base-first 方法拷贝 | 本分叉的实例模型：真引擎面板 + 类方法拷到实例 |

删除：皮肤安装、`hl2sb_derma_menus`、自研控件外观、任何面板池。
桥必须在 GMod `derma/init.lua` 之前加载。

## 2. derma 目录

| 动作 | 文件 |
|---|---|
| 覆盖 | `lua/derma/{init,derma,derma_utils,derma_menus}.lua` |
| 新增 | `lua/derma/{derma_animation,derma_gwen,derma_example}.lua` |
| 删除 | `lua/derma/hl2sb_derma.lua`（内容迁入桥）、`hl2sb_derma_menus.lua`、`hl2sb_skin.lua` |
| 新增 | `lua/skins/default.lua`（GMod 原版皮肤） |
| 保留 | `lua/skins/hl2sb_default.lua` 暂留一轮，确认 GMod 皮肤可用后删 |

皮肤材质：GMod 皮肤只需 `Material("gwenskin/GModDefault.png")`；
`hl2sb/materials/gwenskin/gmoddefault.png`（28865 B）已在仓内，无需再从 VPK 提取。

## 3. vgui 目录

GMod 93 / 分叉 95，同名 77 个全部被覆盖（分叉是重写版）。

**GMod 独有 16 个（需新增）**：
`dcategorycollapse` `dmenuoption` `dpanpanel` `slidebar` `vgui_panellist`
`prop_boolean` `prop_combo` `prop_entity` `prop_float` `prop_generic` `prop_int`
`prop_vectorcolor` `dhtml` `dhtmlcontrols` `fingerposer` `fingervar`

**分叉独有 18 个（逐个处置）**：

| 文件 | 处置 |
|---|---|
| `dproperty_boolean/combo/entity/float/generic/int/vectorcolor.lua` | 删（GMod 用 `prop_*` 命名） |
| `dcategoryheader.lua` `dcollapsiblecategory.lua` | 删（GMod 合并进 `dcategorycollapse.lua`） |
| `dscrollbar.lua` `dscroller.lua` | 删（GMod 用 `slidebar.lua` + `dhscrollbar.lua`） |
| `dtab.lua` | 删（GMod 在 `dpropertysheet.lua` 内注册） |
| `dhorizontaldividerbar.lua` `dverticaldividerbar.lua` | 删（GMod 在 `dhorizontaldivider.lua` 内） |
| `dlistviewline.lua` | 删（GMod 的 `dlistview_line.lua`） |
| `dcheckboxlabel.lua` | 保留并标注（GMod 无对应控件，本分叉自研便捷件） |
| `avatarimage.lua` `controlpresets.lua` | 保留并标注（分叉包装件；GMod 无同名文件） |

**include 表**：`lua/includes/vgui_base.lua` 换 GMod 原版（54 个 include）。
GMod 表里没有的保留件（`dcheckboxlabel` 等）追加到文件末尾并注明原因。

## 4. spawnmenu（P3）

| 动作 | 路径 |
|---|---|
| 新增整树 | `lua/spawnmenu/**`（33 文件，含 `creationmenu/content/contenttypes/*`） |
| 覆盖 | `lua/includes/modules/{spawnmenu,controlpanel}.lua` |
| 删除 | `lua/autorun/client/hl2sb_spawnmenu_gmod.lua`（1430 行自研 v4） |
| 改挂 | `OnSpawnMenuOpen` / `OnSpawnMenuClose` 关掉自研挂接，交给原版 `spawnmenu.lua` 模块 |
| 保留 | 内容注册 autorun（`hl2sb_gmod_npcs.lua`、`hl2sb_gmod_vehicles.lua`、`game_hl2.lua`、`properties*.lua`、`widget_*.lua`） |

## 5. 验证顺序

1. 离线语法：`D:\project\luacheck\lua_gmod.exe -e "local f,e=loadfile('<path>'); print(f and 'OK' or e)"` 逐个过新拷入文件。
2. 离线断言：`lua_dofile_cl derma_lib_test.lua`（按 GMod 语义重写后）。
3. 进图 smoke：C 键开菜单、五页内容、右键属性、文本框输入、玩家模型编辑器。
4. 数据包镜像：`D:\srceng\hl2sb数据包\` 同步改动路径。
5. 双仓提交（内容仓与引擎仓分开）。

## 6. 决策记录

- **2026-10-19：选择方案 B（最小 Lua 桥）**。理由：分叉没有 C++ `vgui.Register` /
  `GetControlTable`（全树零绑定，实现只在待删的 `hl2sb_derma.lua` 里），GMod 的
  `vgui.Create` 返回表对象模型与本分叉的 userdata+拷方法模型不同。走 B 可以让
  **GMod 的 derma 框架与全部控件逐字运行**，只把注册管线留在 Lua；方案 A（C++ 对象
  模型，参考 `D:\tmp\panel_review\panel\lib\lua_registry.cpp`）作为后续清理项。
- **范围**：P2/P3 只替换 `lua/derma/`、`lua/skins/`、`lua/vgui/`、`lua/spawnmenu/`、
  `lua/includes/modules/`；**`lua/includes/init.lua` 与 `extensions/` 保留**——其中的
  Panel 垫片（`NoClipping`、`SetExpensiveShadow`、`SetFontInternal`、`SetWrap`、
  `GetFont`、`Prepare`、`KillFocus`、`DrawFilledRect/OutlinedRect`、`SetWorldClicker`、
  `SetLineHeight`、`HasParent`）在换原版后依然有效，不必进 C++。
- **回滚点**：内容仓分支 `backup/pre-lpanel-rework-20261019-2157`；
  lua 树快照 `D:\tmp\hl2sb_pre_lpanel_backup\hl2sb_lua.zip`。

---

# 执行记录（2026-10-19，P1-P4 文件层完成）

## 已落地

| 阶段 | 内容 | 验证 |
|---|---|---|
| P1 | 共享 Panel 元表新增 20 个方法（文本/光标/多行/模态/焦点/绘制族）；`TextEntry::SetCaretPos/GetCaretPos` | 每个改动 TU 单 TU 编译通过；`client.dll` 部署 MD5 `985FE613BD93F841B43EC881423810DF`；引擎仓提交 `d3045b39b` / `18a8cf729` |
| P2 | `hl2sb_derma.lua` → `hl2sb_bridge.lua`；GMod `derma/` 6 框架文件 + `init.lua`（原文 + 桥前奏 + 皮肤尾奏）；GMod `lua/vgui/` 93 控件；`vgui_base.lua` = GMod 54 条 + 3 条保留件；GMod `skins/default.lua`；`hl2sb_skin.lua` 降级为助手+注册表 | 语法 10/10 + 96/96；悬空 include 0 |
| P3 | GMod sandbox `spawnmenu/` 33 文件 → `gamemodes/sandbox/gamemode/spawnmenu/`；`cl_spawnmenu_gmod.lua` 驱动 + `cl_init.lua` 一行；删除 1430 行自研 v4 | 语法 33/33 + 2/2 |
| P4 | GMod `editor_player.lua` → `gamemodes/sandbox/gamemode/`；`shared.lua` 按 GMod 位点 include；删除自研编辑器 26800 B | 语法 3/3 |

## 预提交闸门（每次提交前重跑）

1. 全仓语法：`python D:\tmp\panel_review\sweep_syntax.py`
   基线（2026-10-19）：**485 文件，2 个失败，均为改动前就存在的测试脚本**
   （`lua/hands_lib_test.lua:126`、`lua/portalgun_lib_test.lua:103`，与本次重构无关）。
2. 悬空 include：`python D:\tmp\panel_review\check_dangling.py` → 必须 0。
3. 引擎侧若再动 C++：单 TU 编译 + `waf build --targets=client` + MD5 核对。

## 提交分组（内容仓，待进图验证后执行）

1. `refactor(derma)`: bridge 重命名 + GMod 框架 7 文件 + 皮肤 + 助手层 + 删死文件
2. `refactor(vgui)`: GMod 93 控件 + `vgui_base.lua` + 删 15 个分叉独有件
3. `refactor(spawnmenu)`: gamemode 树 33 文件 + 驱动 + `cl_init.lua` + 删自研 v4
4. `refactor(player)`: `editor_player.lua` + `shared.lua` + 删自研编辑器
5. `fix(panel)`: `extensions/client/panel.lua` 的 8 个状态垫片

## 静态契约审计（2026-10-19，桥 vs GMod derma）

换原版后 `derma` 全局由 GMod 的 `derma.lua`（`module("derma")`）**整体替换**，桥里挂在
`derma.*` 上的东西会消失。逐条核对过：

| 契约 | 结论 |
|---|---|
| `vgui.Register/Create/GetControlTable` | 在 `vgui` 表上，不被替换 ✅ 桥继续生效 |
| GMod `DefineControl` → `vgui.Register` + `Controls[]` + `_G[name]` | 与桥的 Register 契约一致 ✅ |
| `derma.GetControlList` | GMod 自己的 `derma.lua:88` 提供（桥的同名版失效，无影响；`derma_example.lua:13` 调的就是 GMod 那版）✅ |
| 桥独有的 `derma.InstallConVarLink` / `GetControlTable` / `CursorPos` / `NewCallablePanelTable` / `GetDerivedControlClasses` | 全树**无运行期调用**（只有注释与死文件 `hl2sb_derma_check.lua` 提及）✅ |
| SetConVar 家族 | 改由控件自己 `Derma_Install_Convar_Functions`（GMod 的 dbinder/dcheckbox/dcombobox/dtextentry/dnumberscratch/dnumpad 共 6 个都在调）✅ |
| `derma.DefineSkin/SkinHook/Get*Skin` | 桥/助手层版本**后加载**并覆盖 GMod 版本；GMod 的 `skins/default.lua` 因此注册进本分叉的注册表，`skin["Paint".."Button"]` 命名约定两边一致 ✅ |
| 服务器 realm | 新 `init.lua` 保留了分叉原有的 `if ( not ( ( CLIENT or _GAMEUI ) and surface and vgui ) ) then return end` 前置守卫，服务端不会进 derma ✅ |
| 皮肤继承（`SkinMetaTable`） | 只有 GMod 的 `DefineSkin` 实现；本分叉版不实现继承，`Default` 皮肤不需要 ✅ |

## 遗留：两个分叉测试工具仍按旧控件集写

`lua/derma_lib_test.lua` 与 `lua/autorun/client/hl2sb_derma_check.lua`（全树唯一的
"已删控件"引用来源，共 11 处）仍列着 `DCategoryHeader` / `DCollapsibleCategory` /
`DScrollBar` / `DScroller` / `DProperty_*` / `D*DividerBar` 这些 GMod 没有（或换了名字）的
控件。它们只在被显式调用时创建控件，**不影响加载**，但跑起来会报缺控件——这是 P5
"按 GMod 语义重写 derma 探针" 的一部分，尚未做。

## 明确未做

- **皮肤之外的视觉打磨**：GMod 皮肤的字体用 Tahoma/Roboto（无 CJK），中文经它绘制会缺字；
  分叉原先用 Microsoft YaHei。若中文界面不可接受，改 `lua/derma/init.lua` 的三个
  `surface.CreateFont` 即可（属偏差，非引擎缺口）。
- **HTML/Awesomium 控件族**（`DHTML` 等）：计划书列为不修，`IsLoading`/`RunJavascript`/
  `SetHTML`/`GoBack`/`GoForward`/`StopLoading`/`NewObject` 因此仍缺。
- **`vgui.Register` 的 C++ 实现（方案 A）**：留作后续，当前用 Lua 桥。

