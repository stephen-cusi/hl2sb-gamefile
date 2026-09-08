# AGENT.md — hl2sb (Half-Life 2: Sandbox)

本文件记录 hl2sb mod 的关键工程事实、最近的改动与踩坑,方便后续 AI/开发者快速上手。改完重要代码后请更新此文件。

## 项目结构

- **mod 目录**: `D:\srceng\hl2sb`(游戏运行时目录,含 `gameinfo.txt`、`maps\`, `lua\`, `resource\`, `custom\`, `bin\` 等)
- **引擎源码仓库**: `D:\project\source-engine`(Source 2017 fork;包含 `engine\`, `game\client\`, `game\server\`, `gameui\`, `materialsystem\` 等)
- **Git 分支**: `c_hands_alignment_fix`
- **运行入口**: `D:\srceng\hl2_launcher.exe -game hl2sb -console`(从 exe 所在目录 `D:\srceng\bin` 加载所有 DLL)

## 构建 / 部署

- **重新配置(改了 wscript/配置后)**: `python .\waf configure -T release --build-game=hl2sb`
- **构建单个模块**: `python .\waf build --targets=<TargetName> -j12`
  - 常用目标名: `GameUI`(大写)、`client`、`server`、`shaderapidx9`、`materialsystem`
  - `python .\waf list` 可列出所有目标名
- **必须设置 UTF-8 环境**,否则 msvcdeps 会 UnicodeEncodeError:
  ```pwsh
  $env:PYTHONIOENCODING="utf-8"; $env:PYTHONUTF8="1"
  ```
- **注意**: waf 可能不追踪头文件依赖,改了 `.h` 后如果没重编,删除对应的 `.o`(或整个 `build\<module>\*.o`)强制重编:
  ```pwsh
  Remove-Item 'D:\project\source-engine\build\materialsystem\shaderapidx9\meshdx8.cpp.*.o' -Force
  Remove-Item 'D:\project\source-engine\build\materialsystem\shaderapidx9\shaderapidx9.dll' -Force
  ```
- **部署**: 把 `build\<module>\<Module>.dll` 复制到 `D:\srceng\bin\`(游戏从 exe 所在目录加载 DLL,不是 hl2sb\bin)。用原子替换避免文件占用:
  ```pwsh
  Copy-Item $src $tmp -Force; Move-Item $tmp $dst -Force
  ```
- **DLL 输出位置**: `D:\project\source-engine\build\<module>\<Module>.dll`

## 最近改动(重要)

### 1. GMod 式创建服务器界面(全屏)

把 Source 引擎 gameui 的"创建服务器"小弹窗重写成 GMod 风格的全屏面板。

改动文件(在 `D:\project\source-engine\gameui\`):
- `CreateMultiplayerGameDialog.cpp/.h` — 重写为全屏 `vgui::Frame`。布局:左侧游戏模式列表(Sandbox/Deathmatch/Campaign)、中间地图缩略图网格(3 列卡片)、右侧服务器设置(服务器名/密码/最大玩家数)、右下"开始游戏"、左下"返回主菜单"。
- `PNGImagePanel.cpp/.h`(新增)— 从 `maps/thumb/<地图>.png` 加载缩略图并绘制(无图显示黑色)。
- `GameUI.vpc` / `gameui\wscript` — 登记新文件 + `#define HAVE_PNG`。

关键知识点:
- **地图数据**: `BuildMapGrid()` → `LoadMaps("GAME")` 扫描 `maps/*.bsp`(含 hl2sb/maps、custom/gmod_maps/maps、以及 hl2/hl2mp/garrysmod 挂载的所有地图)。
- **缩略图路径**: `maps/thumb/<地图名>.png`。实际目录: `D:\srceng\hl2sb\custom\gmod_maps\maps\thumb\`(1075 张,128x128 PNG)。
  - 有对应缩略图的 gm_construct/gm_flatgrass/d1_canals_* 等会显示图,其余的(如 sb_field/mm_coop/background*)显示黑色。
- **构建内容放在 `ApplySchemeSettings`(首次调用)而非构造函数**: 在构造函数里调用 `SetSize`/`SetMinimizeButtonVisible`/`SetTitleBarVisible` 等 Frame 标题栏 mutator 会崩(半构建的标题子面板)。所有子控件创建 + 标题栏 chrome 都挪到 `ApplySchemeSettings`(用 `m_bBuilt` 守护),并让 Frame 在 scheme 应用后再 SetSize(全屏)。
- **卡片点击**: `CMapCardPanel` 用 `CMouseMessageForwardingPanel`(和 gameui 的 `CBonusMapPanel` 相同模式)把点击转发给宿主导航 → `OnMapSelected`。输入面板要 `SetMouseInputEnabled(false)` 避免拦截。
- **英文/中文编码**: MSVC 默认按 GBK/codepage 读取 .cpp,源码里写中文会报 C2001/C2143。一律用 `#GameUI_*` 本地化 token(在 `D:\srceng\hl2sb\resource\gameui_english.txt`,UTF-16LE)。`#GameUI_Back`=Back, `#GameUI_StartGame`=Start Game, `#GameUI_ServerName`=Server name, `#GameUI_MaxPlayers`=Max. Players。

### 2. 创建服务器菜单崩溃修复(先前)

之前点击"创建服务器"闪退。根因:在构造函数里操作 Frame 标题栏。修复:内容构建挪到 `ApplySchemeSettings`,已解决(见上)。

### 3. gmod 地图进图闪退(整数除零)→ shaderapidx9 修复

**现象**: 进 gm_construct / gm_flatgrass 这类 gmod 地图时闪退(不是菜单问题,直接 `+map gm_construct` 也崩)。

**根因**: 引擎 DX9 shader 设备在画天空盒/世界时,某个动态网格被喂了一个**无效/零顶点格式**,`VertexFormatSize()` 返回 0,随后 `CVertexBuffer::ChangeConfiguration` 计算 `m_nBufferSize / vertexSize` 触发 **integer divide-by-zero**(0xC0000094),在 `shaderapidx9.dll` 崩溃。

- 崩溃调用链: `CShaderAPIDx8::GetDynamicMesh → CMeshMgr::GetDynamicMesh → CBufferedMeshDX8::SetVertexFormat → CDynamicMeshDX8::SetVertexFormat → CMeshMgr::FindOrCreateVertexBuffer (+0x1e5)` 内联的 `CVertexBuffer::ChangeConfiguration`。
- 确切位置: `materialsystem\shaderapidx9\dynamicvb.h` 的 `ChangeConfiguration()`。

**修复**: 已提交 `5319b0ab`。在 `ChangeConfiguration` 里把 `m_VertexSize` clamp 到 1,避免除零:
```cpp
m_VertexSize = ( vertexSize > 0 ) ? vertexSize : 1;
m_VertexCount = ( m_VertexSize > 0 ) ? ( m_nBufferSize / m_VertexSize ) : 0;
```
这使 gmod 地图能进且不再闪退。**注意副作用**: 那个无效顶点格式的天空盒 mesh 用 stride=1 绘制 → 天空盒(skybox)渲染成纯白/不显示。如需天空盒也正常显示,需深入 mesh 兼容问题(可能需改 bsp 或对 0-format mesh 特殊处理)。

**已知状态**:
- gmod 地图能玩、不闪退;其他(城市/草地/模型/武器/手)渲染正常;仅天空盒为白色。
- 这个"天空盒白"不是 gmod shader 缺失 —— hl2sb 的 `gameinfo.txt` 已挂 `mod garrysmod/garrysmod.vpk` + `game garrysmod`,且 `Sky` shader 在 `stdshader_dx9.dll` 里存在(`materialsystem\stdshaders\sky_*.cpp`)。
- 天空盒白更可能是 gm_construct 天空盒几何用了无效顶点格式(引擎画不出)。

### 4. 其它曾做的改动(可参考)

- `game/client/hl2mp/hud_killfeed.cpp`(新增)— GMod 式击杀播报 HUD(独立元素,按截图配色,渐变淡出)。ConVar: `cl_drawdeathnotice`, `hud_deathnotice_time`。
- `game/client/menu/sm_menu_list.cpp` — 按住 Q 开 smenu;关闭了菜单的键盘焦点(`SetKeyBoardInputEnabled(false)`),否则 WASD 会被 vgui 吞掉无法移动。
- `game/client/cdll_client_int.cpp` — 加了 `gameeventmanager->LoadEventsFromFile("resource/ModEvents.res")`,否则 `entity_killed` 事件的扩展字段在客户端读为空。
- `game/server/baseentity.cpp` — 丰富了 `entity_killed` 事件(attacker_uid/attackername/victimclass/weapon)。

## 调试技巧

- **崩溃日志**: 引擎崩溃会 dump 到 `D:\srceng\hl2sb\dumps\crash_*.mdmp`(文件名带异常类型如 intdividebyzero / accessviolation)。
- **用 cdb 分析 minidump**: `cdbX64.exe -z <dump> -c ".symopt+ 0x40; .reload; .ecxr; k 40"`
  - cdb 路径: `C:\Users\12\AppData\Local\Microsoft\WindowsApps\cdbX64.exe`
  - 符号路径 `_NT_SYMBOL_PATH`: `D:\srceng\bin;D:\srceng\hl2sb\bin;SRV*C:\Symbols*https://msdl.microsoft.com/download/symbols`
  - **注意**: shaderapidx9/engine 等引擎 DLL 的 PDB 不在 srceng\bin;可把 `build\<module>\<Module>.pdb` 拷到 `D:\srceng\bin\` 或在 `_NT_SYMBOL_PATH` 加 PDB 目录,才能解析真实符号(否则显示 `CreateInterface+N`)。
- **用启动参数复现进图崩溃**: `D:\srceng\hl2_launcher.exe -game hl2sb -console +map <map>`
- **用 cdb 断 second-chance**(只断真崩溃,不断 first-chance 正常异常):
  ```
  sxd 0xC0000005
  sxd 0xC0000094   # div-by-zero
  g
  ```
- **控制台日志**: `D:\srceng\hl2sb\ds_debug.log`(con_logfile)和 `D:\srceng\engine.log`。
- **用户提供的地图缩略图**: `D:\srceng\hl2sb\custom\gmod_maps\maps\thumb\<地图名>.png`

## 用户偏好

- 中文回复。
- 不喜欢被要求复制粘贴日志,倾向让 AI 自行读取文件。
- 倾向自主执行。
- 地图缩略图: 有图显示图,没图显示黑色;地图卡片尺寸匹配缩略图。
