# hl2box TODO 清单

hl2box（半条命 2 沙盒，迁移前内部名 hl2sb）对 GMod 的功能移植打钩清单与遗留工作。
图例：`[x]` 完成 / `[ ]` 待做 / `[~]` 部分完成 / `[-]` 刻意不做（含理由）。
库清单基准：GMod wiki 全部 88 个 Lua 库（经 libgmod 权威绑定表核对，2026-10-10）。

## 一、Lua 库（对照 GMod 88 库）

### C 引擎绑定（游戏侧直接可用）

- [x] `net`（lnet.cpp；undo 三消息等已在用）
- [x] `cam`（cam.Start3D/End3D，halo/FPB 在用）
- [x] `input`（LIInput；in_mouse 物理枪 E 冻结视角同源）
- [x] `sql`（lsql.cpp；playerpdata 扩展在用）
- [x] `sound`（sound.Add 等已验，`hl2sb_soundadd_test.lua`）
- [x] `file`（全合同 + 封锁名单，`file_lib_test.lua`）
- [x] `render` / `surface` / `vgui`（含 POT/非 POT 纹理修复）
- [x] `util`（CRC/SteamID64/Base64/LZMA/Ray 系列，`util_lib_test.lua`）
- [x] `bit`（lua/src/bit.c）
- [x] `debugoverlay`（livdebugoverlay）
- [x] `system`（system.IsAndroid，触控分支在用）
- [x] `engine`（部分——`IsMounted` 守卫恒 false，见"刻意不做"）
- [~] `ents` / `entity` / `game` / `gameevent`（entity_killed 扩展字段已加）
- [~] `navmesh`（NextBot 侧有面，API 差异未全量清点）

### Lua 模块（lua/includes/modules/，GMod 同名）

- [x] hook / concommand / timer（暂停/失败/RepsLeft 语义）
- [x] undo（GMod 逐字，双通知修复，`undo_lib_test.lua`）
- [x] constraint（1757 行）/ construct / cleanup / duplicator（1048 行）
- [x] numpad / properties / presets / spawnmenu / controlpanel / search / menubar
- [x] draw / effects / halo / markup / killicon / language / list
- [x] player_manager（玩家类系统 + AddValidModel 桥）
- [x] gamemode / baseclass / team / cookie / cvar(s) / resource / drive / widget
- [x] achievements（16 个惰性桩——GMod 侧成就服务器不存在）
- [x] utf8（GMod 原样）/ string / table / math 扩展（LerpVector/LerpAngle 等）
- [x] save + gmsave（includes/gmsave/ 目录）
- [x] umsg / usermessage（旧 API，GMod 亦弃用，仅兼容面）
- [~] scripted_ents / weapons / weapon（注册与 SWEP 生态可用； duplicator 端到端未验）
- [~] matproxy（player_weapon_color 等已重写；全集未核对）

### 缺口（GMod 有、我们没有）

- [ ] `physenv`（GetGravity/SetGravity/GetAirDensity/SetAirDensity/GetPerformanceSettings）
- [ ] `serverlist`（服务器列表查询）
- [ ] `mesh`（IMesh 动态网格；lrender 有零星命中，库未建）
- [ ] `steamworks`[-]（无 Steam 接入，刻意不做）
- [ ] `frame_blend` / `video`（小众，待需求）
- [ ] `SendLua` 通道（现为收下不做事 + 一次性告警）
- [ ] `GM:CalcView` 载具派发（FPB 载具眼睛吸附依赖，见主日志 FPB 节）

## 二、Gamemode 与游戏系统

### 已完成

- [x] base gamemode（`LUA_BASE_GAMEMODE="base"`，sandbox 经 table.inherit 继承）
- [x] 计分体系：`GM:DoPlayerDeath(ply, attacker, dmginfo)` 三参派发 + Lua 计分（引擎零计分，GMod 同位）
- [x] 记分板：GMod 原版骨架 + nosteam `AvatarImage`（data/avatars 文件方案）+ 麦克风图标 + `+showscoreboard`
- [x] player_manager 每关生成 + frags/ping 双端网络化 + 构造清零
- [x] 拾取 HUD（五参事件 + Lua 折叠 + `BumpWeapon`/`EquipAmmoOnly` 发射点）
- [x] undo 通知链（deathmatch `GM:OnUndo` 单消费者）
- [x] 创建服务器全屏 UI（gamemode 列表/地图缩略图/设置；`gamemode` convar 被 RevertFlaggedConVars 打回的修复 + 地图分类定 gamemode）
- [x] spawnmenu v4（Entities/Weapons/NPCs/Vehicles 四注册表、本地化、快照缩略图、触控 96px 模式）
- [x] 玩家模型菜单（扫描 + 插件注册 + 文字列表 + SpawnIcon 快照）
- [x] 上下文菜单（hl2sb_contextmenu_gmod.lua）
- [x] NPC/载具/座位注册表（base_npcs 59 条移植；`IsMounted` 守卫）
- [x] 弹药系统（ammo 模块 + luasrc_ApplyAmmoTypes + `gmod_maxammo` 逃生口 + INFINITE_AMMO 通道）
- [x] 本地化（GMod en/zh-cn/zh-tw properties 拷入 + 分叉自有 token）
- [x] 物理枪 GMod 架构：五钩子、DT_PhysBeam、贝塞尔三缎带 + 精灵簇、骨骼抓取、E 旋转（视角冻结 + mousedx 上行）、滚轮 IN_WEAPON1/2、扫掠门控、冻结列表、世界模型 w_Physics
- [x] gmod_hands 第一人称手（DeleteOnRemove/TransmitWithParent/死亡复活保持/SetBodygroup）
- [x] 手势同步 TE_PlayerAnimEvent（远端武器 activity 翻译广播、exclude overlay_vars、m_nOrder 加固）
- [x] firstpersonbody 支撑（SetBoneMatrix/RenderOverride/ManipulateBone*/裁剪面；安卓 gl_ClipDistance）
- [x] SENT 伤害派发（OnTakeDamage + TraceAttack 双入口门）、父子变换 parent-aware、WorldSpaceAABB
- [x] trace 结果合同（Normal=射线方向、缺省 MASK_SOLID、ignoreworld）
- [x] halo 架构（PostDrawEffects 链 + FB 对 + pp/copy|add|sub 材质 + physgun halo）
- [x] SWEP 生态主干（GMod 字段读面、weapon_base、世界模型、acttable 双键）
- [x] HL2 十武器 + physgun + toolgun（C++ 版 weapon_toolgun）
- [x] 击杀播报 C++ HUD（hud_killfeed）+ ModEvents.res
- [x] gmod 地图可进（shaderapidx9 除零修复 5319b0ab；天空盒白为遗留观感）

### 部分

- [~] halo：E1（`IMaterial:SetString` 数值向量解析）、E2（DrawScreenQuad 内建 Push2DView）引擎修复未落地；v3 重写丢失待重做（详见主日志 2026-10-10 更正）
- [~] 物理枪对齐：见下方 P1 清单（答疑轮已逐项反编译定案，纯机械）
- [~] 语音：引擎 RecordStop 修复已部署；cl_voice.lua 面板未移植
- [~] NextBot：base_nextbot + C++ 侧在；API 差异未清点
- [~] 聊天链：服务端 PlayerSay 在；OnPlayerChat/chat.AddText 客户端半环缺
- [~] duplicator：模块在（1048 行），工具枪存档端到端未验
- [~] 字体/选队/成就显示：随场景补

## 三、TODO（按优先级）

### P1

- [ ] 物理枪对齐清单（施工图 = `D:\srceng\gm_physgun\physgun_v2`，全部已反编译定案）：
  - [ ] ConVar：`physgun_teleportDistance` 250→0、`physgun_maxAngular` 5400→5000、`gm_snapangles` 45→0；新增 `physgun_DampingFactor`(0.8)、`gm_snapgrid`(0)；全部 `FCVAR_REPLICATED`；range 边界 128..32768 / 32..256
  - [ ] 质量：`SetMass(50000)`→45678 + savedMass 哨兵 -1 + 车辆类名判定（jeep/apc/jeep_old）
  - [ ] 冻结走 SecondaryAttack + 0.5s 双攻击冷却门（现 IN_ATTACK2 按下沿无冷却）
  - [ ] 动画二态：持物 RECOIL1(204)/空闲 174（现仅 0xB5 one-shot 回 idle）
  - [ ] 删 `Weapon_Physgun.Scanning` 循环声（参考双端零音效）
  - [ ] R 键 10ms 闸；hold 门 `(buttons & 0x801) == IN_ATTACK`
- [ ] halo E1：`IMaterial:SetString` 数值向量解析（litexture.cpp:746，"$color [1 1 1]" 黑屏根因）
- [ ] halo E2：`render.DrawScreenQuad` 内建 Push2DView（当前依赖外部 Push2D 配对）
- [ ] physgun_halo_rework v3 重做（E3/E4 现状先核对；AGENTS 10-09 条目已标注"未落地"）
- [ ] cl_voice.lua 移植：`voice_status.cpp` UpdateSpeakerStatus 四类事件 → `hook.Run("PlayerStartVoice"/"PlayerEndVoice", ply)`；保留 voice_modenable 自动开麦与 m_VoicePlayers 位；`Player:IsPlayerSpeaking` 绑定（挂点情报已齐）

### P2

- [ ] 聊天链客户端半环：`OnPlayerChat` / `chat.AddText`
- [ ] `SendLua` 通道（需 client-only Lua 队列，GMod 同形）
- [ ] `variable_edit.lua`（引擎侧无派发）
- [ ] `SetVoiceVolumeScale`（滚轮绑定缺）
- [ ] `physenv` 库（Get/SetGravity、AirDensity、PerformanceSettings）
- [ ] NPC 客户端 `m_iMaxHealth` 网络化（玩家侧已修 50d1f475；NPC 判满血/可治疗的 GMod SWEP 全部误判）
- [ ] duplicator + 工具枪端到端验证（存档/复制粘贴全链）
- [ ] vphysics ragdoll 加固（来源 `_vphysics_gmod_diff.md`，R3 已做 e298658e）：
  - [ ] R1：CPhysCollide ledge walk 加守卫（崩溃不可达）
  - [ ] R4：bad-ledge / queued functor 探针（定位撕挂对象）
  - [ ] R5：workshop .phy 加载期合法性校验（运行期地雷 → 加载期警告）

### P3

- [ ] `cl_deathnotice.lua` 与 C++ killfeed 共存策略
- [ ] `player_pickup`（+use 携带）子系统（hook id 177/178）
- [ ] 运行时探针：`gm_snapangles 0` 时 E+SHIFT 写 NaN 的实测（静态已证实的原版 bug）；2x 抓距 vs 束半距意图确认
- [ ] NextBot API 差异全量清点（数据包 `_nextbot_api_diff.py` 有底子）
- [ ] `serverlist` / `frame_blend` / `video` 库（待需求）
- [ ] 游戏内热挂载（照 exs mountsteamcontent 结构，MountGameContentByAppId + GameContent.txt）
- [ ] GMod 天空盒白观感深挖（gm_construct 无效顶点格式 mesh；除零已修）
- [ ] SWEP 钩子补面：`TranslateFOV` / `HUDShouldDraw` / `AdjustMouseSensitivity` / `DrawWeaponSelection`（fork 选枪 HUD 结构不同，需单独轮）

## 四、刻意不做（勿再提）

- [-] DHTML/CEF 全族（无浏览器层）
- [-] Steam 头像/steamworks（nosteam 文件方案：`data/avatars/<steamid64|name>.png`）
- [-] `IsMounted`/`engine.GetGames` 真实现（守卫恒 false 是 GMod 式注册文件依赖的语义）
- [-] `util.GetModelMeshes`、Decal 系、`PixelVisible`、undo 二进制导出（GMod 本来就没有）
- [-] gamemode 计分放引擎侧（GMod 放 Lua 的就放 Lua，移植期双计债）
- [-] `SWEP:ShouldDropOnDie`/`CustomAmmoDisplay`/`EquipAmmo`（无引擎路径，判定见旧 SWEP 计划）

## 五、工程速查（合并自 AGENT.md，2026-10-10 起本文件为唯一清单）

### 构建与部署

- 配置：`python .\waf configure -T release --build-game=hl2sb`（引擎仓）；构建：`python .\waf build --targets=client,server -j12`
- 单 TU 预编译防呆：`python tools/hl2sb_compile_one.py <game/相对路径.cpp>`（引擎仓 tools/）
- MSVC 构建需 UTF-8 环境：`$env:PYTHONIOENCODING="utf-8"; $env:PYTHONUTF8="1"`
- waf 头依赖不可靠：改公共头后按 mtime 清消费目录 .o（细则见主日志铁律）
- 部署表：`server.dll`/`client.dll`+PDB → `hl2sb\bin\`；`engine.dll`/`materialsystem.dll`/`shaderapidx9.dll`/`GameUI.dll`/`vgui2.dll` 等 → `D:\srceng\bin\`（搞错位置 = "修复无效"假象）
- 部署前关游戏（DLL 被占用）；原子替换：`Copy-Item $src $tmp -Force; Move-Item $tmp $dst -Force`
- DLL 产物：`D:\project\source-engine\build\<module>\<Module>.dll`

### Lua 加载与 hook 机制

- 加载序：`luasrc_init` → dofolder(extensions/modules/game/shared/server) → LoadWeapons → LoadEntities → LoadGamemode(base) → LoadGamemode(active) → SetGamemode；继承 = gamemode.lua `register()` 的 table.inherit
- `gamemode` convar（REPLICATED）会被 gameui `RevertFlaggedConVars` 打回——CreateGame 已修（记值回拼 map 串 + 地图分类定 gamemode）
- C++ 侧：`BEGIN_LUA_CALL_HOOK/END_LUA_CALL_HOOK(nArgs,nresults)` + `RETURN_LUA_*`；`RETURN_LUA_NONE` 下 Lua 返回 false = 跳过 C++ fallback，返回 nil = 继续
- 错位自查：`ds_debug.log` 的 `ERROR: GAMEMODE: '<Hook>' Failed`；hook 计数错位报 `attempt to call a string value`
- Lua 侧：hook.lua = 注册钩子先跑、回退 GAMEMODE 方法；CallBody 出错会把 gamemode 方法摘掉（HUD 哑火的隐形根因）
- gamemodes/ 下的 lua 一律 UTF-8 无 BOM；给 CBasePlayer 加 virtual 必须加在类声明末尾

### 调试

- 崩溃 dump：`hl2sb\dumps\crash_*.mdmp`（文件名带异常类型）；分析：`python D:\project\_dsh_mdmp.py <dump>`
- cdb：`cdbX64.exe -z <dump> -c ".symopt+ 0x40; .reload; .ecxr; k 40"`；second-chance 门 `sxd 0xC0000005` / `sxd 0xC0000094`
- 符号：`_NT_SYMBOL_PATH` 含 `D:\srceng\bin;D:\srceng\hl2sb\bin`（PDB 同拷才能出真符号）
- 控制台日志：`hl2sb\ds_debug.log`（con_logfile）+ `D:\srceng\engine.log`
- 部署生效快查：二进制里搜特征串（如 `gmod_maxammo`）
- 库级回归：`lua_dofile <name>_lib_test.lua`（服务端）/ `lua_dofile_cl`（客户端）

## 六、来源与清理记录（2026-10-10）

本清单合并并删除了以下旧文档（要点已吸收进上文）：

- `AGENT.md`（本仓 364 行工程日志；构建/部署/hook 机制/弹药系统/调试技巧并入第五节，过时段——LUA_BASE_GAMEMODE=deathmatch、38 hooks、gmod_camera 不可用、player_manager 缺失——以本清单与主日志为准）
- `数据包/AGENT.md`（镜像副本，随正本删除）
- `source-engine/GMod_SWEP_compat_plan.md`（SWEP 兼容计划；缺口并入第三节 P2/P3，已修项——GetWeaponColor、玩家 maxhealth 网络、DrawWeaponSelection 参数——以主日志为准）
- `D:\project\wiki\PHYSGUN_GMod_REVERSE.md`（已被 gm_physgun 还原仓 + `D:\tmp\dec` 归档 + 引擎 `docs/gmod_physgun_decompile_report.md` 取代）
- `D:\project\_vphysics_gmod_diff.md`（vphysics 对照与 hutao 崩溃调查；R3 已落地，R1/R4/R5 并入第三节 P2）
- `D:\project\_exs_gamemode_compat_study.md` / `_exs_crash_analysis.md`（exs 迁移研究；结论已沉淀，热挂载想法并入 P3）

权威工程日志：`D:\project\AGENTS.md`（主日志）+ `D:\project\source-engine\AGENTS.md`。
