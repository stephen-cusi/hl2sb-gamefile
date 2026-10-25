# hl2box 移植状态与 TODO 清单

hl2box（半条命 2 沙盒，迁移前内部名 hl2sb）对 GMod 的功能移植打钩清单。
图例：`[x]` 完成 / `[ ]` 待做 / `[~]` 部分完成 / `[-]` 刻意不做（含理由）。
库清单基准：GMod wiki 全部 88 个 Lua 库（经 libgmod 权威绑定表核对，2026-10-10）。
最近全量复核：2026-10-14；2026-10-23 增量核对 Lua 布局、base/sandbox 文件与已有 native 派发点，详见 `docs/lua_layout.md`。原“完成”不等于与当前 GMod 逐字一致或已通过所有实机验证。

## 2026-10-24 原版 Gamemode 完整迁移

本轮按阶段执行。参考仅使用实际 Steam GMod 安装目录；原版 Lua 保持原样，缺口修在原生层。下面未完成项不能按文件存在或同名绑定标为完成。

- [x] 迁移前完整备份当前 lua/ 与 gamemodes/ 到本地临时目录，并记录两仓已有改动。
- [~] 清点 base/sandbox 原版文件、旧实现、原生消费者及加载顺序；归档取证先查各 DLL 的 _index.txt，缺失才新增。
- [x] 接入原版 gamemode 注册、BaseClass、Folder/FolderName 和规范 entities 目录；保留旧目录兼容扫描并保持 campaign/deathmatch 可加载。
- [x] 语音面板、计分板、目标提示、死亡通知替换为原版 Lua；死亡协议和拾取事件已接入原版 HUD 钩子。
- [x] 替换 base 客户端入口和默认面板生命周期；旧 C++ killfeed 绘制/死亡事件桥已移除，拾取只保留原生事件转发。
- [x] 替换 base 服务端/共享/player_class/动画与生命周期；修复重复出生装备、重复布娃娃、复活尸体和死亡掉枪。
- [~] 替换 sandbox 服务端/共享命令、通知、存档与驱动；原版出生、冻结/解冻、菜单文件已接入，保存仍是兼容适配。
- [~] 把 gamemode 实体、效果和武器迁回原版目录；完整目录已迁移的类已停用旧副本，仍依赖虚拟 LUA 查询或有兼容差异的类暂留旧路径。
- [x] 静态清单与逐模块离线运行检查；覆盖 137 个 gamemode/依赖 Lua 的原生 CompileFile 编译、gamemode 继承、生命周期、死亡/拾取/冻结、UI 和新绑定合同。
- [x] 所有本轮修改 C++ 已单 TU 检查，client/server 增量构建通过；部署待本轮结束前完成并校验 DLL/PDB。
- [ ] 完整重启后的游戏验证：进图、出生、换枪、语音、TAB、死亡通知、Q/C、工具枪、保存/读档及切图。
- [-] SteamAPI/CEF 等外部服务不作为迁移阻塞；按调用契约跳过或提供明确空桩，不把空桩算作已实现。

### 本轮已核实的周边功能

- [x] `ai_serverragdolls` 菜单选项：第二轮按当前 GMod 实现补齐 native 注册与 NPC 创建时快照；开启后新 NPC 使用服务端保留尸体，默认仍为 0。上一轮关于 `CBaseAnimating` 已消费的结论不准确，已纠正。`effects_unfreeze` 由原版 `phys_unfreeze.lua` 消费。
- [x] 物理枪解冻：原版 `Player:PhysgunUnfreeze`、`CanPlayerUnfreeze`、`PlayerUnfrozeObject` 和 `phys_unfreeze` 已恢复，冻结/解冻提示合同通过。
- [x] 出生状态：player class 的速度、生命、护甲、手电、掉枪、队友碰撞/绕行设置都会按原版调用；掉枪已连接 native 消费，队友碰撞/绕行 native 消费仍待补。
- [x] 击杀/拾取：原版死亡 net 六种编码、原版 `DeathNoticeEvent` 解析和 `HUD*PickedUp` 钩子均有离线合同；实际多人网络顺序待游戏验证。
- [~] Derma/VGUI：原版 base/sandbox Derma 与面板脚本已载入；`ContextMenu` 关闭焦点保留在独立兼容层，CEF/HTML 面板功能不纳入本轮。

### 2026-10-24 第二轮回归修复

- [x] 重进地图崩溃：崩溃转储与 DLL/PDB 时间戳匹配。Combine/Metropolice 死亡掉落错误使用 CHalfLife2 类型，掉落计时覆盖多人规则的 response vector，退出地图释放时崩溃。改用正确多人规则，并初始化多人掉落计时；实际函数回归复现旧写坏并验证 2000 次修复后调用不污染容器。
- [x] 图标编辑器：补 `Entity:GetSequenceCount` 真实客户端绑定，包含虚拟模型合并序列计数；原版 IconEditor 的序列排序、搜索和滑块离线合同通过。
- [x] NPC 保留尸体：补 `ai_serverragdolls` 注册及真实 native 路径，按 GMod 在 NPC 创建时快照；开启后须重新生成 NPC，关时保留普通客户端尸体路径。自定义模型和实际尸体画面仍未实机验证。
- [x] 出生默认武器：子代理修复 native 默认 `cl_defaultweapon=weapon_physgun`、`Player:HasWeapon` 真布尔和旧默认武器兼容层；原版 Lua 保持不改，用户本轮要求主线程只集成部署，不另改配置。
- [ ] 图标编辑器 `SetLOD` 仍为旧空实现，不能把全部编辑器功能标为完成。
- [ ] 菜单 realm 仍有原生日志缺口：ConVar 构造未开放，Material 的真实客户端构造由 luaopen_ITexture 注册，单独 luaopen_IMaterial 只创建元表，导致原版 util.lua 捕获 nil。后续需修 native 初始化顺序，不改原版 Lua。
- [x] 第二轮所有改动单 TU 和离线合同通过；client/server 增量构建 21.158 秒，DLL/PDB 已直接部署且四对 SHA256 一致。未启动游戏，实机重进图与尸体/编辑器验证仍由用户进行。

### 2026-10-24 第三轮回归修复

- [x] 移除旧 physgun halo autorun，消除捕获 hook 短路与原版同名渲染 hook 覆盖；使用原版 Sandbox halo 开关和目标列表，开/关/开离线回归通过。
- [x] 独立兼容层补 Sandbox 禁用 HL2 武器时的默认持枪回退：首选武器不在库存且拥有物理枪时选物理枪，有效自定义首选仍保留，原版 Lua 和用户配置未改。
- [x] 原生服务端尸体创建完成后派发 CreateEntityRagdoll，原版 Sandbox 转移 NPC 的 undo/cleanup 记录，原实体删除后 Z 可移除尸体；实际派发宏与原版 Lua 合同通过。
- [x] client/server 构建成功（23.060 秒），DLL/PDB 已直接部署到实际游戏 bin，四对 SHA256 一致。未写结果报告、未启动游戏、未提交推送。
- [ ] 实机验证 halo 开关、无 HL2 配给时持枪、NPC 尸体撤销。保留尸体开关不是立即删除开关；普通客户端尸体受回收队列管理，开关只影响之后生成的 NPC。

### 2026-10-24 手指造型与工具说明回归

- [x] 撤回没有执行证据的重复菜单加载兜底；原版 Sandbox 客户端 include 链保持原样。日志中的 ContentSidebar 已能证明菜单实际创建过。
- [x] 修复原生 gmod_toolmode 缺 USERINFO 标志：原版工具枪读取玩家配置选择服务端工具，客户端修改现在参与 userinfo 传输。
- [x] 恢复原生 SWEP:DrawHUD 派发。原版 base HUD 不负责调用武器 HUD；工具名称/说明与手部选择标记仍由原版工具枪 Lua 绘制。
- [x] 参照当前游玩版本的 CBoneManipulate / DT_BoneManipulate 实现保存位移、角度和缩放的网络控制对象，替换上一轮瞬时骨骼消息。第四参数支持服务端本地值与网络值区分；相同值不重复弄脏骨骼缓存。
- [x] 移除服务端骨骼无操作兼容壳；LookupBone 和 math.Distance 保留真实绑定。FingerPoser、FingerVar 与 finger 工具现在逐字节匹配当前 GMod 原文件。
- [x] 原版手指工具/控件离线合同、实际 C++ 控制对象及 HUD 派发合同通过；变更 TU、双端增量构建和包含路径大小写检查通过，DLL/PDB 四对 SHA256 已核对后直接部署。证据位于 D:/tmp/finger_native_20261024/，原生取证已入各自归档索引。
- [ ] 完整重启后的手测：右键选中布娃娃的手，按 C 拖动手指点位、切预设、切换左右手，检查工具枪左上说明；再验证多人晚加入与重新进图后的姿势。
- [~] 整套骨骼操纵仍不能标为全部对齐：物理骨处理、服务端骨架消费、jiggle 与所有骨骼缩放/子骨联动尚未完成全量核验。离线服务隔离测试不等于实际 VGUI、骨骼渲染或网络验证。

### 仍未完成或刻意跳过

- [ ] `SetNoCollideWithTeammates`、`SetAvoidPlayers` 仍只有脚本字段，尚无真实 native 碰撞/推开消费者。
- [ ] `engine.WriteSave`、完整 `.gms`/`LoadGModSave` 原生存档链未实现，当前 save_load 是文件适配。
- [ ] taunt camera 的完整 native CalcView/CreateMove/ShouldDrawLocalPlayer 与跨图 transition 参数仍需实机核对。
- [ ] SteamAPI 功能（Workshop 查询之外的好友、档案、网页服务）不实现；`Player:ShowProfile` 是明确空桩。
- [ ] CEF/HTML/JavaScript 面板不实现；相关菜单路径保留空桩或现有 VGUI 替代，不把它们标成完整 GMod 功能。
- [ ] `GetVoiceVolumeScale` 当前是本地比例存储，未接入 Steam voice mixer 的增益控制。
- [ ] 实机未启动：出生、多人击杀/拾取、TAB、Q/C、工具枪、冻结解冻、保存读档和切图必须完整重启后验证。

过程只更新本 TODO；临时测试、快照和取证留本地，不新增结果报告，不自动启动游戏或提交推送。

### 2026-10-24 Lua 启动面清理

- [x] 原版公共库及 base/sandbox Lua 本轮未改；仅调整分叉 includes/init.lua 的兼容入口；本轮迁移的兼容代码收纳到 `lua/hl2sb/compat/`，由两个 `hl2sb_compat.lua` 入口按顺序加载。
- [x] 移出会覆盖原版行为的旧自动脚本：强制关闭跌落伤害、重复写玩家颜色、未引用的显示名全局和空准星入口。
- [x] 移出重复的帮助/队伍命令注册；`gm_showhelp`、`gm_showteam` 由原生命令处理，仅保留旧 `gm_showspawns` 兼容命令。
- [x] 二进制模块示例改为手动测试，不再随服务器和客户端启动强制 `require`。
- [x] 删除重复的通知兼容入口；渲染过滤器已有原生无操作绑定，Sandbox 的 AddNotify 由 gamemode 提供。
- [x] Lua 清理前快照、哈希和变更清单：`D:/tmp/hl2sb_lua_cleanup_20261024/`。
- [x] 14 个本轮 Lua 文件语法通过；实际双端入口离线执行保留 59 个 NPC 和 15 个载具/座椅；录制、错误钩子、字体阶段/重入合同通过。9 项移动逐字核对通过，其余 Lua/gamemode 与清理前快照一致。
- [ ] 本轮未启动游戏；需完整重启后验证 autorun 顺序、载具/NPC 注册、错误提示和准星菜单。

## 2026-10-23 Lua 整理与搬运缺口

- [x] 33 个手动诊断脚本归到 `lua/tests/`；原自动加载的字符串测试改为手动运行。
- [x] 移除未引用的旧 Sandbox BuildMenu 两文件、禁用的 Experiment 总入口及五个休眠辅助文件。
- [x] 仍在使用的枚举、武器注册桥、字体/面板与通知适配归到 `lua/hl2sb/compat/`；保留 native 启动所需的公共 modules/extensions。
- [x] 入口 `includes/init.lua` 只保留明确的加载顺序；移除已由 native hover 负责的 `vgui.Create` tooltip 包装。
- [x] 击杀通知移回 `base/gamemode/cl_deathnotice.lua`；既有重力枪回调拆回 `base/gamemode/gravitygun.lua`，行为保持。
- [ ] native gamemode 实体加载器支持原版 `gamemodes/<name>/entities` 层级；当前工具/实体在 `content/lua` 或全局 `lua`，已经搬过并在使用，不能直接改目录导致不再注册。
- [ ] base 缺的原版文件：effects 的 `base.lua`、`dof_node.lua`，entities 的 `prop_effect.lua`、`ragdoll_motion.lua`。
- [ ] sandbox 缺的原版效果文件：`balloon_pop.lua`、`entity_remove.lua`、`inflator_magic.lua`、`lasertracer.lua`、`phys_unfreeze.lua`、`wheel_indicator.lua`。
- [ ] sandbox 缺的编辑实体：`base_edit.lua`、`edit_fog.lua`、`edit_sky.lua`、`edit_sun.lua`；示例内容 `nb_example.lua`、`manhack_welder.lua` 也尚无对应文件。
- [~] `cl_notice.lua` 的 AddNotify 已在 base 适配里；sandbox `save_load.lua` 仍是 base 文件存储适配，原生 `.gms` 存取链未补。
- [~] base 玩家类 `taunt_camera.lua` 仍是旧适配，gamemode 另有活动相机实现，不能当重复文件直接删除。

文件映射后的 base/sandbox 共 178 个原版 Lua：107 个内容一致、53 个有适配/差异、16 个文件缺失、1 个内联适配、1 个部分适配。这里只是文件及源码检查，不把 native 同名实现、空默认方法和未实测功能误算成已完成。清理前的 Lua/gamemodes 快照及逐文件清单留在 `D:/tmp/hl2sb_lua_cleanup_20261023`。

## 一、Lua 库（对照 GMod 88 库）

### C 引擎绑定（游戏侧直接可用）

- [x] `net`（undo 三消息等已在用）
- [x] `cam`（cam.Start3D/End3D）
- [x] `input`
- [x] `sql`
- [x] `sound`
- [x] `file`（全合同 + 封锁名单）
- [x] `render` / `surface` / `vgui`
- [x] `util`（CRC/SteamID64/Base64/LZMA/Ray 系列）
- [x] `bit`
- [x] `debugoverlay`
- [x] `system`
- [x] `physenv`（Get/SetGravity、Get/SetAirDensity、PerformanceSettings、Simulation 系列全表；仅 SetPerformanceSettings 是直通桩）
- [~] `engine`（`IsMounted` 守卫恒 false，见"刻意不做"）
- [~] `ents` / `entity` / `game` / `gameevent`
- [~] `navmesh`（NextBot 侧有面，API 差异未全量清点）

### Lua 模块（GMod 同名）

- [x] hook / concommand / timer（暂停/失败/RepsLeft 语义）
- [x] undo（GMod 逐字，双通知修复）
- [x] constraint / construct / cleanup / duplicator
- [x] numpad / properties / presets / spawnmenu / controlpanel / search / menubar
- [x] draw / effects / halo / markup / killicon / language / list
- [x] player_manager（玩家类系统 + AddValidModel 桥）
- [x] gamemode / baseclass / team / cookie / cvar(s) / resource / drive / widget
- [x] achievements（惰性桩——GMod 侧成就服务器不存在）
- [x] utf8 / string / table / math 扩展（LerpVector/LerpAngle 等）
- [x] save + gmsave
- [x] umsg / usermessage（旧 API，仅兼容面）
- [~] scripted_ents / weapons / weapon（注册与 SWEP 生态可用；duplicator 端到端未验）
- [~] matproxy（player_weapon_color 等已重写；全集未核对）

### 缺口（GMod 有、我们没有）

- [ ] `serverlist`（服务器列表查询）
- [ ] `mesh`（IMesh 动态网格）
- [x] ~~`SendLua` 通道~~（已实现：走 lua_run_cl 控制台命令传输，Entity:SendLua + BroadcastLua，2026-10-14 核实 lbaseentity_shared.cpp）
- [ ] `GM:CalcView` 载具派发——2026-10-04 做过一版又回滚（First Person Body 车内 pose-zero→强制 SetupBones 序列导致座位模型每帧振动，b58583e4..b4d639bf 有完整记录）；等 addon 侧帧序问题解决后再接

## 二、Gamemode 与游戏系统

### 已完成

- [x] base gamemode（sandbox 经 table.inherit 继承）
- [x] 计分体系：`GM:DoPlayerDeath(ply, attacker, dmginfo)` 三参派发 + Lua 计分（引擎零计分，GMod 同位）
- [x] 记分板：GMod 原版骨架 + nosteam `AvatarImage`（data/avatars 文件方案）+ 麦克风图标 + `+showscoreboard`
- [x] player_manager 每关生成 + frags/ping 双端网络化
- [x] 拾取 HUD（服务端声明种类 + Lua 折叠 + 弹药袋合并）
- [x] undo 通知链（单消费者）
- [x] 创建服务器全屏 UI（gamemode 列表/地图缩略图/设置；gamemode 选择不被打回）
- [x] spawnmenu（已替换旧 v4，自原版 Sandbox creation/context 菜单移植；外围 native 兼容仍有差异）
- [x] 玩家模型菜单（已替换旧扫描/文字列表，使用原版 editor_player 与 SpawnIcon/ModelImage）
- [x] 上下文菜单
- [x] NPC/载具/座位注册表（base_npcs 移植）
- [x] 弹药系统（ammo 模块 + 引擎应用 + 全局 maxammo 逃生口 + 无限弹药通道）
- [x] 本地化（GMod en/zh-cn/zh-tw properties + 分叉自有 token）
- [x] 物理枪 GMod 架构：五钩子、束网络实体、贝塞尔三缎带 + 精灵簇、骨骼抓取、E 旋转（视角冻结）、滚轮、扫掠门控、冻结列表
- [x] gmod_hands 第一人称手（死亡复活保持）
- [x] 手势同步（远端武器 activity 翻译广播、手势层不网络化）
- [x] firstpersonbody 支撑（SetBoneMatrix/RenderOverride/ManipulateBone*/裁剪面；安卓裁剪面）
- [x] SENT 伤害派发（OnTakeDamage + TraceAttack 双入口）、父子变换 parent-aware
- [x] trace 结果合同（Normal=射线方向、缺省 MASK_SOLID、ignoreworld）
- [x] halo 架构（PostDrawEffects 链 + 帧缓冲对 + 物理枪 halo）
- [x] SWEP 生态主干（GMod 字段读面、weapon_base、世界模型、acttable 双键）
- [x] HL2 十武器 + physgun + toolgun
- [x] 击杀播报 HUD + 游戏事件扩展
- [x] gmod 地图可进（顶点格式除零修复；天空盒白为遗留观感）
- [x] 聊天链全环：GM:OnPlayerChat（MsgFunc_SayText2 派发，返回真抑制默认打印）+ chat.AddText（C++ 绑定，实体/颜色混排）+ OnChatTab/ChatTextChanged/StartChat/FinishChat（hud_basechat.cpp 引擎派发）+ base cl_init 五钩子逐字移植
- [x] 语音 HUD：base cl_voice.lua（GM:PlayerStartVoice/PlayerEndVoice + 右上说话面板列表）+ util.IsPlayerSpeaking（真响度通道）+ Player:Set/GetVoiceVolumeScale（按 steamid 记忆）
- [x] Lua 错误体系（2026-10-14）：GM:OnLuaError 五参派发（error/realm/stack 帧表/addon 名/id）+ 遗留 LuaError 四参兼容 + hook 回调崩溃统一上报 + GMod 式左上错误提示条（HUDPaint 载体）+ 错误菜单带 realm/addon 标注
- [x] RunString/RunStringEx 全局 + lua_run/_cl 走同核（GLua 改写、空串/字节码拒收、handleError 语义）
- [x] 武器钩子批（2026-10-13）：PlayerDroppedWeapon/PlayerAmmoChanged/PlayerSwitchWeapon/PostEntityFireBullets/EntityEmitSound/WeaponEquip + GravGunPickupAllowed/Punt/OnPickedUp/OnDropped 全派发；SWEP 侧 TranslateFOV/HUDShouldDraw/AdjustMouseSensitivity/DrawWeaponSelection 四钩子接线
- [x] net 库 GMod 形态（直接 Lua 传输 + 全量测试套件）
- [x] FireBullets 参数钳制（Num 1-128、Force 0-100，GMod 同界；防超规格 SWEP 打爆粒子顶点池）
- [x] Sandbox 属性放行与世界交互：GM:CanProperty / GM:CanDrive / GM:PlayerDriveAnimate / GM:LimitHit + 3D 世界提示（cl_worldtips.lua，AddWorldTip + GM:PaintWorldTips）+ 提示系统（cl_hints.lua，GM:AddHint/ThrowHint）
- [x] variable_edit（base 侧 GM:VariableEdited / GM:CanEditVariable 移植）
- [x] 未派发的 gamemode 钩子补齐（2026-10-21，按参考实现的派发点逐个逆向核对落地）：
  - [x] `GM:VGUIMousePressAllowed`（client，vgui2 的 Panel 鼠标按下路径先问脚本，答 true 吞掉这次点击；游戏侧装回调）
  - [x] `GM:NetworkEntityCreated`（server 脚本实体生成 + client 首个数据更新）
  - [x] `GM:EntityNetworkedVarChanged`（client，NW 值真变化时才报，带实体/名字/旧值/新值）
  - [ ] `GM:PrePlayerDraw` / `GM:PostPlayerDraw`（client）——**语义已逆向坐实**（答 (实体, drawType 整数)，带重入守卫；参考实现是在玩家层包住绘制，位置在模型渲染之外），但**从模型绘制内部应答会炸**：钩子里脚本再画一次模型（夜视插件就是在钩子里画自己的面片）就撞上正在渲染的场景，整帧坏掉（半屏深红方块）。要落地必须换到"嵌套绘制安全"的位置（参考实现那样在玩家层包绘制，或把应答挪到帧末）
  - [ ] `GM:GetMotionBlurValues`（client）——**语义已逆向坐实**（参考实现是四次各带一个数调用、四个数回写；分叉这边是一次带四个数），同样**不能在后处理里应答**：那也是渲染过程中调脚本。落地要挪到渲染之外
- [ ] 其余未派发的 gamemode 钩子（2026-10-21 全量比对参考实现的派发表后剩下的）：
  - 渲染：`PreDrawSkyBox` / `PostDrawSkyBox` / `PostDraw2DSkyBox` / `SetupSkyboxFog` / `SetupWorldFog` / `NeedsDepthPass` / `CaptureVideo` / `DrawMonitors` / `PreventScreenClicks`（`SpawniconGenerated` 已有 native ModelImage 生成后派发，不再列为缺失）
  - 实体网络：`OnEntityWaterLevelChanged` / `OnCrazyPhysics` / `OnNPCDropItem` / `OnAchievementAchieved` / `ClientSignOnStateChanged` / `CreateClientsideRagdoll` / `InputMouseApply`
  - 玩家：`PlayerSpray`（连带 `game.AddDecal` 贴花管线，与 gmod_tool 的 paint 工具同一条链）/ `PlayerBindPress` / `PlayerCanHearPlayersVoice` / `PlayerClassChanged` / `PlayerHandleAnimEvent` / `PlayerFireAnimationEvent` / `OnChangeActivity` / `OnCloseCaptionEmit` / `OnPauseMenuShow` / `VehicleMove`（`PlayerButtonDown`/`PlayerButtonUp` 已有 shared native 按键差分派发）
  - `GM:TranslateActivity`（gamemode 级活动翻译钩子；分叉目前只有 `WEAPON:TranslateActivity`）
  - `GM:OnClientLuaError`（分叉已有 `OnLuaError`，缺 client 变体）

### 部分

- [~] halo：`IMaterial:SetString` 数值向量解析未落地（halo.lua 已用 SetFloat 绕开，黑屏不影响；但第三方插件若用 SetString 传 "[1 1 1]" 向量仍会黑）；DrawScreenQuad 2D 推送已修（MODEL 矩阵括号）
- [x] 物理枪对齐（2026-10-14 落地）
- [~] NextBot：base_nextbot + C++ 侧在；API 差异未清点
- [~] duplicator：模块在，工具枪存档端到端未验
- [~] 字体/选队/成就显示：随场景补
- [~] 聊天框外观：功能链全通，但仍是 HL2MP 的 C++ 聊天框皮肤，非 GMod 的 Lua 皮肤聊天框

## 三、TODO（按优先级）

### P1

- [x] 物理枪对齐清单（2026-10-14 落地，引擎 01a798760/11dc7d0cc/07749645f/dc414be2 + 内容 dc87ce8）：
  - [x] ConVar：`physgun_teleportDistance`=0、`physgun_maxAngular`=5000、`gm_snapangles`=45；新增 `physgun_DampingFactor`(0.8)、`gm_snapgrid`(0)；全加 REPLICATED 与边界
  - [x] 质量：抓取抬升到 45678 + 车辆判定保留原质量 + 恢复质量逻辑
  - [x] 冻结走 SecondaryAttack + 0.5s 双攻击冷却门 + ACT_VM_PRIMARYATTACK(181) 动画
  - [x] 视空间无俯仰限制 E 旋转 + Shift+E 45 度吸附
  - [x] 抓取端点与光束端点坐标系单次逆变换对齐（消灭抓 NPC/道具拐弯）；UTIL_TraceEntity 实体扫掠门控（消灭拖拽遁地）
  - [x] 滚轮在 CInput::KeyEvent 拦截武器切换，服务端正常消耗累加器拉近推远
  - [x] 删扫描循环声（参考双端零音效）
  - [x] R 键 GM:OnPhysgunReload 解冻并通知 UnfrozeObjects 气泡与音效
- [ ] halo：`IMaterial:SetString` 数值向量解析（"$color [1 1 1]" 黑屏根因；halo.lua 自身已绕开，此项为第三方插件兼容）
- [ ] `GM:CalcView` 载具派发第二轮：解 First Person Body 车内振动的帧序问题后重接（历史见"缺口"节）

### P2

- [x] `variable_edit.lua`（GM:VariableEdited / GM:CanEditVariable 移植落地）
- [ ] NPC 客户端 `m_iMaxHealth` 网络化（玩家侧已修；判满血/可治疗的 GMod SWEP 全部误判——2026-10-14 核实 DT_BaseCombatCharacter 仍无此字段）
- [ ] duplicator + 工具枪端到端验证（存档/复制粘贴全链）
- [ ] vphysics ragdoll 加固：ledge 遍历守卫、坏对象定位探针、workshop .phy 加载期校验
- [ ] AddCSLuaFile + Lua 缓存文件（LCF）管线：方案已交付（激活 luacachefile.cpp 休眠管线 + 服务端绑定 + 客户端解包），等拍板；落地后传送枪进图会开始报 "Couldn't find cl_fonts.lua"（GMod 正确行为）
- [ ] OnLuaError 配套余项： spam guard（GMod 5 错/1s 同款）、`lua_error_url` POST 上报、错误菜单 Problems 式分组

### P3

- [ ] `cl_deathnotice` 与 C++ 击杀播报的共存策略
- [ ] `player_pickup`（+use 携带）子系统（HL2 物理炮的 OnPlayerPhysicsPickup/Drop 钩子已在 physcannon 路径；GMod 式 +use 携带本体未做）
- [ ] 运行时探针：`gm_snapangles 0` 时 E+SHIFT 写 NaN 的实测（静态已证实的原版 bug）；2x 抓距 vs 束半距意图确认
- [ ] NextBot API 差异全量清点
- [ ] `serverlist` / `frame_blend` / `video` 库（待需求）
- [ ] 游戏内热挂载（挂载游戏内容清单化）
- [ ] gmod 地图天空盒白观感深挖（无效顶点格式 mesh）
- [ ] 主菜单 HTML 内核选型（搁置，2026-10-11）：menusystem 独立模块（引擎在 GameUI 旁加载、菜单离屏渲染成 RGBA 走 vgui 贴图上传）模块壳与管线已验证；RmlUi 首版已整体撤回——menu.html 是 AngularJS 单页应用，需真 DOM+JS 引擎，排版渲染器不适用。候选：
  - Ultralight：轻量 WebKit，官方多架构二进制（含安卓），集成代码量最小；非商用免费、商用需授权
  - CEF 原版：GMod 菜单同款 Chromium，兼容最高；每平台 100-200MB 且需 helper 子进程，官方二进制不含安卓（需自行出包）
  - 系统 WebView：Windows WebView2 + 安卓系统 WebView，零体积真 Blink；需逐平台写贴图管道，Linux 无对应方案
  - Sciter：最轻、渲染进缓冲最简单、免费含商用；自有 JS 方言跑不动 AngularJS 页面

  恢复时重建模块壳（引擎加载点已随撤回删除）并接入离屏渲染。

## 四、刻意不做（勿再提）

- [-] 游戏内 DHTML/CEF 面板族（无浏览器层；主菜单 HTML 内核选型是独立搁置项，见 P3）
- [-] Steam 头像/steamworks（nosteam 文件方案：`data/avatars/<steamid64|name>.png`）
- [-] `IsMounted`/`engine.GetGames` 真实现（守卫恒 false 是 GMod 式注册文件依赖的语义）
- [-] `util.GetModelMeshes`、`PixelVisible`、undo 二进制导出（GMod 本来就没有）。**注意**：`Decal 系`整体不算"GMod 没有"——参考实现的 `game` 库里有 `game.AddDecal`（gmod_tool 的 paint 工具靠它），本仓缺它属于待做项（见上面 P1/P2 的 `PlayerSpray` 一条），别按"刻意不做"处理
- [-] gamemode 计分放引擎侧（GMod 放 Lua 的就放 Lua，移植期双计债）
- [x] `SWEP:CustomAmmoDisplay` 已有 native 入口；主弹药 HUD 按返回表决定显示与数值，medkit 使用原版 callback，2026-10-23 修复。副弹药自定义字段还未完整接入，不能再写成“无引擎路径、刻意不做”。
- [~] `SWEP:ShouldDropOnDie` 已有 native 投票适配；`EquipAmmo` 仍需单独核对消费路径，移除旧合并“刻意不做”结论。


## 2026-10-25 Evil API / Crawler 与 PR 69 审查

- [x] 先阅读安装的 evil_api，再核对 evil_crawler 的加载、初始化、攻击及渲染调用；插件 Lua 未修改。
- [x] 审查原 PR 并按当前 Steam 版本核对相关原生行为；新增取证已归档至 D:/tmp/dec/client.dll 与 server.dll，索引已补。
- [x] 修正动态光照接口；mesh 使用受限顶点缓冲并在 End 内完成原生提交，避免 Lua 报错留下 GPU 锁或错误的 context 引用计数。
- [x] 复用已有网络骨骼控制器，补 HasBoneManipulations、服务端 GetChildBones、骨骼 jiggle 状态及实际客户端消费；补 flags 别名、观战/离车、物理攻击者与持物查询、net normal 编解码、Vector:SetUnpacked。
- [x] 当前主干原生 Lua 加载器运行原插件的 API、server autorun、实体文件，验证 Victim 捕获、Initialize 赋值、300 帧 Crawl 和原版 Flesh.Tube；另验证 mesh 中断/边界、骨骼状态与观战状态转换。引擎/渲染/物理服务使用离线隔离，不代表游戏内通过。
- [x] 所有改动 cpp 单 TU 检查；client/server 最终构建成功（19.458 秒），DLL/PDB 直接部署到 hl2sb/bin，四份 SHA256 清单 D:/tmp/evil_pr69_20261025/deployment.json。
- [ ] 用户完整重启后测试生成、显示、追踪、NPC/玩家抓取、挣脱与释放、删除及重新进图。
- [ ] 用户验证后处理 PR；本轮未提交、未推送、未合并。

审查说明：D:/project/source-engine/docs/evil_crawler_compatibility_review.md。动态 mesh 子集覆盖该插件；静态 IMesh 和完整 mesh 库仍不宣称完成。PR 中 Vel/BaseHeight/wish 报错未在当前主干与原插件的离线链重现，不修改插件来掩盖其初始化问题。


## 2026-10-25 Evil 抓取无限布娃娃回归

- [x] 读取00:51日志并确认首错 GetAmmo 缺失：Body 已创建，但装备保存失败，观战/HUD状态与StartDrag均未执行，导致后续抓取更新重复生成。
- [x] 逆向核对并补 Player:GetAmmo 的正数弹药ID稀疏表（本叉64槽），原生 StripWeapons 保留弹药/防护服，Give(class,true)按no-ammo布尔语义处理。
- [x] 原插件完整抓取/恢复链复现旧错误；修复后4轮、每轮600次更新仅创建1具布娃娃，离线核对观战HUD状态、血量/护甲/防护服/弹夹/备用弹药及双玩家隔离。物理/网络/相机服务为隔离模拟，不能宣称游戏内通过。
- [x] 3个CPP单TU检查通过，client/server构建19.401秒，DLL/PDB直接部署并核对4份SHA256。证据 D:/tmp/evil_capture_20261025。
- [ ] 用户完整重启游戏后复测抓取、HUD与相机、布娃娃数量、挣脱/释放和装备恢复；通过后再处理PR。

上一轮名字审计把 Vehicle:GetAmmo 误当 Player:GetAmmo 已实现；启动和移动测试没有覆盖 Take。这两项不足已写入审查说明，插件原始Lua保持哈希不变。


## 2026-10-25 Evil 双模型与分解后无法重生

- [x] 读取01:18日志：NPC和玩家各生成一次抓取布娃娃，随后有脚本死亡通知，无新抓取报错；排除上轮GetAmmo重复生成。
- [x] 核实旧KillSilent：普通伤害被观战DAMAGE_NO挡住，只通知未进入死亡状态。按当前GMod直接死亡流程修正；普通Kill同步改为直接死亡事件路径。
- [x] 本地玩家镜面显示例外现在遵守隐藏标志和观战状态，避免抓取本体与替身同时显示，正常镜面资格保留。
- [x] 服务端补真实GetRagdollEntity查询，客户端移除固定NULL空实现，原版PostPlayerDeath消费者不再缺方法。
- [x] 原插件Victim.Kill与原版死亡/重生方法回归：复现旧问题，验证静默/后死亡回调顺序、延时按键重生、可选inside模式释放和常规Kill；可见性与已有4轮抓取回归通过。图形/网络/物理为隔离服务，游戏内待确认。
- [x] 单TU检查与client/server构建通过20.469秒，DLL/PDB直接部署并核对4份SHA256；证据 D:/tmp/evil_death_20261025。
- [ ] 用户完整重启后测试NPC抓取、玩家双模型、分解死亡后攻击/跳跃重生、主动释放与正常镜面显示；通过后再处理PR。

## 2026-10-25 单人切多人重进地图崩溃

- [x] 核对最新转储与日志：多人第二次初始化时，file.Exists 的 VPK 目录枚举复制文件名崩溃；小块分配器空闲链中出现物理约束监听器虚表地址，属于堆状态损坏，不能归因为 Lua 文件查询本身。
- [x] 修正物理环境销毁顺序：先关闭约束/碰撞/对象回调，监听器保留到物理对象、延迟删除、流体和底层环境清理结束，避免清理过程中使用已释放监听器。此路径确定存在释放后访问风险；是否为本次唯一堆损坏来源仍待实机复测。
- [x] 统一 Lua 文件加载入口检查插件禁用状态，覆盖 include/CompileFile 加载的工具脚本；日志已证实 door 入口跳过但工具脚本仍执行并报缺少接口。
- [x] 两个改动源文件单 TU 通过，vphysics/client/server 构建成功，实际析构函数离线生命周期合同通过。六个 DLL/PDB 已直接部署，源目标 SHA256 全部一致。
- [ ] 完整退出后按原流程复测：单人进图，禁用 door，再以多人进入同一地图。未启动游戏，不能把离线验证视为实机结案。

临时取证与部署哈希：D:/tmp/sp_mp_crash_20261025/。未创建 result.txt，未提交推送。


## 2026-10-25 重生仍卡观战：待实测状态定位

- 用户确认双模型消失、正常肢解，但不能正常重生，攻击时武器闪现；设置均为默认。最新日志无对应Lua错误。
- [ ] 此问题尚未确认修复。上一轮Spawn隔离模拟显式清理观战，不能证明真实MP出生链通过。
- [x] 当前版原生Spawn已取证归档；本轮只加限量原生诊断，不猜测修改游戏行为。自动记录服务端输入/死亡思考/真实Spawn入口出口、观战状态/目标与客户端StartCommand前后输入；每端限40条。
- [x] 单TU检查及client/server构建20.972秒通过，DLL/PDB部署并核对4份SHA256；D:/tmp/evil_respawn_20261025。
- [ ] 用户完整重启，复现抓取分解后点击攻击/副攻击/跳跃，随后直接读日志定位真实中断环节并修复；最终PR前移除临时诊断。
- 崩溃由另一会话处理，本任务不继续排查或修改崩溃相关代码。


## 2026-10-25 胡桃抓取后索引缓冲区报错

- [x] 日志最后一帧血迹效果后报38866>32768；本次无新dump，不套用旧01:57 AV。
- [x] 当前Steam studiorender逆向确认单张新模型贴花超过16384索引时回滚；本叉遗漏该逻辑，现补回新增顶点/索引和全局计数回滚，旧血迹保留。插件与模型不改，缓冲区不扩容。
- [x] 实际旧/新提交代码与原生IB容量检查离线复现同一错误；50轮回滚、16384边界、旧贴花/历史/计数和独立LOD回归通过。投影几何/GPU为隔离服务，实际游戏待测。
- [x] 单TU通过，studiorender构建4.112秒，DLL/PDB直接部署D:/srceng/bin并核对SHA256。证据 D:/tmp/hutao_decal_20261025；原版取证已归档索引。
- [ ] 用户完整退出重启，再测胡桃被抓/拖动/撕咬与开枪血迹；通过后再处理PR。


## 2026-10-25 Evil 死后卡观战：客户端吞重生键

- [x] 读取02:53日志：真正死亡、重生等待已过、无held/inside限制，但仅移动键进入服务端，攻击/副攻击/跳跃均缺失。旧诊断按状态合并而忽略阶段，未打印death_think不能证明未调用。
- [x] 先读归档，再核对当前Steam版本：GMod派发PlayerBindPress后走聊天/HUD/武器；没有本叉将观战按键转换成spec命令的拦截。修正C++兼容输入链，原插件/原版Lua不改。
- [x] 实际旧/新KeyInput、原生按键位、原hook库与原版PlayerDeathThink回归复现旧问题；新路径三个按键均到达Spawn调用边界，覆盖Lua否决、等待、松键、观战模式、聊天/控制台/HUD/武器和栈平衡。真实Spawn/网络/UI服务未在游戏中验证。
- [x] 删除全部本轮临时重生探针。相关单TU与client/server构建通过20.602秒，DLL/PDB直接部署，4份SHA256一致；原插件Lua哈希未变。证据 D:/tmp/evil_input_20261025，取证已归档索引。
- [ ] 用户完整重启后分别测试肢解死亡与红温一击死亡，等待两秒再按攻击/副攻击/跳跃；确认恢复正常游玩后再处理PR。未提交推送、未启动游戏、未写resulttxt。


## 2026-10-25 Evil 空格挣扎无进度和抓取无缠绕

- [x] 先读03:25最新日志，无对应插件Lua报错。用户确认SPACE可见、填充条不增长；原插件只有填充条和按键亮起，没有数字计数。
- [x] 核实服务端StartCommand原派发在CBasePlayer::PreThink，但实际CHL2_Player::PreThink不调用该基类，原插件Struggled从未收到输入。对照当前GMod移到命令入口，删除旧派发，保证每条命令一次并在按键状态采样前执行。
- [x] 客户端生成的NetworkVar读取遗漏Entity分支，GetVictim/GetPrey一直为空，缠绕角色无法生成。复用已有完整类型解码器，保留本地预测/服务端覆盖，支持目标晚到和NULL。
- [x] 实际原生代码及未改插件回归复现旧问题：服务端按下/松开增长、持续按住不重复；原版客户端Draw生成26点缠绕曲线，原HUD按复制进度增长。另覆盖不同受害者、实体晚到/切换/清空、其他网络类型和栈平衡。网络/碰撞/GPU为隔离服务，实机待测。
- [x] 相关CPP单TU通过，client/server构建19.751s；DLL/PDB直接部署，4份SHA256一致，39份原插件Lua哈希未变。证据 D:/tmp/evil_struggle_20261025，原版取证已归档索引。
- [ ] 用户完整退出重启，快速反复按下并松开空格观察填充条和挣脱，再观察玩家/NPC/尸体抓取时缠绕。尚未提交推送，未启动游戏，未写resulttxt。


## 2026-10-25 Evil 适配提交与 PR 收尾

- [x] 本会话22个文件已英文提交并推送到box-experiment：1ecacd94c61de2b0293fa6bdd20898d296ec46d6。提交快照19个CPP编译单元通过；与已审查索引逐文件blob一致。
- [x] PR #69已回复修复提交、补丁与审查文档链接，并以修正版取代原因关闭（未合并冲突旧实现）；评论6388951846。
- [x] 同文件载具改动按块排除，其他会话的崩溃/载具改动、addons、ivp、thirdparty和运行数据未提交。内容仓TODO仅留本地记录。
- [ ] 最新挣扎填充条与缠绕视觉仍待用户完整重启实测；关闭PR不等于宣称所有实机路径已验证。


## 2026-10-25 载具原版Lua基础与第三人称回归

- [x] 先读03:25退出日志和既有取证索引。本轮只处理载具，不续查Evil死亡/崩溃；游戏未启动。
- [x] 原版base_vehicles.lua逐字迁入，删除旧车辆/座椅注册兼容文件和无效Player车辆别名；普通Jeep使用prop_vehicle_jeep_old，补原生工厂别名，不凭上车方向制造第二驾驶座。普通Jeep与Jalopy的原版注册保持区分。
- [x] 原版Vehicle扩展从entity.lua的完整Vehicle Extensions段逐字迁入；保留原版base gamemode相机/移动/动画Lua。原版drive模块和三个drive基类/属性文件逐字恢复。Entity兼容层仅将车辆保留DT槽3接到原生复制字段。
- [x] 双端补VehicleMove实际派发、CMoveData:KeyPressed、预测期间真实GetCurrentCommand滚轮；移除两套旧C++相机状态写入，Ctrl边沿/滚轮距离由原版GM:VehicleMove控制。
- [x] 当前GMod原生入车不使用SDK的IsPassengerVisible否决；移除该旧门造成的EF_NODRAW，第三人称驾驶员进入渲染链。drawviewer也统一影响本地第一人称判定。座位取静止序列，局部坐标只转一次世界坐标，保留当前车辆动画。
- [x] 座椅统一Vehicle元表；基础驾驶员/乘客/视角查询走真实接口，校正有效性、realm和失败返回。移除伪客户端物理API、服务端Vehicle:GetAmmo，修正CheckExitPoint失败、物理控制器不存在返回、参数速度重复单位换算，补质量中心及遗漏车轮/悬挂写入。
- [x] 补独立的网络化实体驾驶状态及原版Start/EndEntityDriving回调，避免弱Lua表丢状态；DrawWorldModel按原生语义控制当前武器，不隐藏玩家。原版drive.lua无需改动。原版座椅活动按活动名注册，避免改公共活动枚举布局。
- [x] 离线合同执行实际C++绑定与原版Lua：15个注册、6个车辆扩展、座椅元表、DT互通、Ctrl边沿、滚轮上下限、相机墙体过滤和drawviewer、25轮实体驾驶开始/切换/结束及武器显示、参数往返与新增字段、32组方向/入口座位变换均通过；图形/网络/物理服务为隔离环境，不等于游戏内通过。
- [x] 改动CPP单TU通过；消费变更头的旧game对象按范围清理，client/server构建成功。DLL和PDB共4份已直接部署hl2sb/bin，SHA256逐份相等；D:/tmp/vehicle_base_20261025/deployment.json。取证归档与索引更新，原版Lua哈希记录original_lua.json。
- [ ] 用户完整退出重启：新生成普通Jeep，从前后左右上车；Ctrl切换第一/第三人称，滚轮调距，转动车身与行驶查看坐姿和模型，再测Airboat/Pod/普通椅子/PHX座椅、上下车与多人远端乘员显示。
- 范围限制：本轮恢复载具Lua基础和原生接入，不宣称新增EP2多乘客底盘、超过本叉4个物理轮对象的载具后端或所有第三方载具插件均已实测。新网络类要求客户端/服务端DLL成对更新。本轮未提交推送、未动addons/运行数据/数据包，未写resulttxt。


## 2026-10-25 载具首次实测失败后的局部回归修复

- 用户04:55实测仍有方向盘手臂缺失、Ctrl相机失效、下车手臂消失。上一节的离线通过不能作为这些实机问题结案。
- [x] 先读新日志，确认原版CalcView第391行Angle(QAngle)缺复制构造，错误后旧hook库删除GM.CalcView，后续相机无法恢复。只采用用户_apply_angle_compat_once.ps1中的Angle局部补丁，没有执行其中无关物理枪修改或自删除。
- [x] 撤掉上轮新增的坐车GetRenderAngles返回GetAbsAngles旁路。现有SetRenderAngles直接写该引用，身体插件临时覆写原本会污染实体绝对角缓存；恢复动画渲染角通道，座位朝向仍由既有动画状态机维护。
- [x] 回归新增真实有效gmod_camera与完整原版CalcView：先复现旧复制构造报错并删除回调，再验证新构造25轮第一/第三人称/下车切换保持相机回调。1000次实际渲染角覆写/还原不改实体朝向。原版Lua和插件未改，渲染/网络/物理服务仍为隔离，实机未验证。
- [x] 子代理独立读取当前GMod原生输入与已部署DLL/PDB：实际RunCommand已调用VehicleMove；GMod CInput与HUD也没有车辆专用滚轮吞键门，因此没有新增猜测性按键拦截。未确认独立Ctrl故障原因，保留实测项。
- [x] Angle与玩家CPP单TU通过，client/server最终构建40.956秒；DLL/PDB四份已直接部署并逐份核对SHA256。
- [ ] 完整重启后复测：首次上车即测试Ctrl与滚轮；第一人称身体手臂是否扶方向盘；连续上下车及切换工具枪/相机后手臂是否恢复。如仍失败应继续读该次日志定位，不能宣称全部修复。

## 2026-10-25 载具第三人称卡颈部与下车手臂复核

- [x] 先读05:26新日志：本轮没有此前的Angle复制或CalcView报错；用户已确认车内第一人称正常。
- [x] 相机原生Lua射线过滤器漏掉游戏规则碰撞组检查，导致原版CalcVehicleView的相机射线命中车内玩家自身；补齐规则，保留墙体和普通实体碰撞。
- [x] 核对当前参考的手臂原生依赖：SetTransmitWithParent必须按父实体的接收者与隐藏状态决策，旧的仅PVS补发实现不足。补齐原生父传输决策，保持手臂可以随父实体隐藏并恢复，拒绝向其他玩家泄漏。
- [x] 按用户要求将lua/entities/gmod_hands.lua逐字替换为当前游玩GMod的原版文件，SHA256一致；原版gamemode及第三方插件Lua不修改。
- [x] 改动CPP单TU通过，client/server增量构建20.843秒通过；真实C++函数离线回归覆盖射线自碰撞、墙体/道具、手臂1000次隐藏/恢复及接收者隔离；原载具回归保持通过。
- [ ] 完整退出并重启，确认首次上车Ctrl切换第三人称与滚轮缩放，再切回第一人称；Jeep/airboat连续上下车，检查物理枪和工具枪的手臂。离线测试不等于实机通过。

取证、测试、DLL/PDB部署SHA256记录：D:/tmp/vehicle_base_20261025。未启动游戏、未提交推送、未创建resulttxt。

## 2026-10-25 不同入口上车初始身体落位调查

- [x] 按用户澄清对照同样的第一人称身体插件；排除把问题误判为持续漂移或有插件即正常。
- [x] 当前GMod原生入车、附件查询、父子挂接、视图模型与渲染角度取证已归档；固定驾驶座位不存在按入口选择永久座位的分支。
- [x] 修正确定的眼高初始化顺序错误：先清蹲姿并规范站姿眼高，再SetPassenger保存/清零；旧顺序会覆盖载具零眼高，蹲姿进入还可能保存错误退出眼高。
- [x] 六组真实规范化片段/SetPassenger合同复现旧问题并通过新路径；原载具回归通过。单TU与client/server构建通过18.694秒，DLL/PDB直接部署并核对SHA256。
- [x] 扩展现有hl2sb_anim_debug日志，记录双端局部位置/角度、渲染角、眼角、当前眼高及姿态；无额外骨骼构建或插件改动。
- [ ] 不同入口身体/手部差异的完整根因尚未确认。完整重启后用hl2sb_anim_debug 1从至少两个异常入口进同一Jeep，中间下车，再设0；比较位置/朝向与骨骼姿态，不能用眼高合同测试冒充手部几何验证。

本轮调查详情：D:/tmp/vehicle_base_20261025/entry_pose_findings.md。未开游戏、未提交推送、未写resulttxt。

### 2026-10-25 用户复测与提交范围

用户反馈本轮载具问题已基本修复，授权提交两个仓库的现有有效改动。GameUI及其开局设置配套文件仍由另一会话进行，排除提交；运行数据、插件安装目录与临时诊断文件不提交。完整因果定位保留现有诊断，不将基本修复写成所有场景全部验证。


### 2026-10-25 Original Lua migration: first integrated batch

- [x] Rechecked D:/tmp/lua_compare_20261025/REPORT.md against the current Steam installation. Of its 54 modified paths, 39 now match original GMod content, preserving repository line endings for submission. This is an integrated batch, not completion of the entire migration.
- [x] Restored 17 VGUI controls plus autorun/menubar, including original label input, category traversal, color controls, model panel, slider, frame and spawn icon behavior. Existing fingerposer/fingervar changes from another session were preserved.
- [x] Restored original math/ease, list, cleanup, scripted_ents, markup, menubar, effects, spawnmenu, undo, weapons, javascript utility and save filters. Added original gmsave/physics. Runtime compatibility lives separately in hl2sb/compat/core_modules.lua.
- [x] Restored original draw, killicon, halo, hook and concommand. Legacy spellings live in compat/dispatch.lua and compat/drawing.lua. Native bootstrap loads type helpers before modules capture them, installs legacy dispatch aliases immediately, filters client modules from the server and defers notification until Derma is ready. Native tables are distinguished from completed Lua modules; failed loads remain retryable.
- [x] Moved the unchanged notification implementation to original includes/modules/notification.lua and removed the duplicate includes/notification.lua path. Kept original motionsensor.lua; unavailable Kinect queries remain explicit compatibility stubs.
- [x] Restored original net extension. Native code publishes type/capacity constants before loading it, preserves double floating-point bits instead of truncating to int64, and supplies row-major 4x4 matrix IO. Vector:ToTable now returns the original numeric array, so original vector.lua no longer needs its Lua replacement.
- [x] Added original overlay, sobel, stereoscopy, sunbeams and texturize. Existing motion_blur lazy initialization remains pending native texture initialization work.
- [x] Fixed the small menu startup errors: ConVar and real Material constructors are registered before original Lua captures them. Menu-owned ConVars survive map teardown and are released or transferred at menu shutdown. Native AddConsoleCommand, requested flags and autocomplete now support original concommand.lua.
- [x] Tests: original file syntax; original math/ease, font/glyph measurement, hook veto/return shape/error retention, console dispatch/aliases, undo/cleanup, five postprocess scripts and net tables/colors. Extracted actual native loader linked against the Lua runtime passes realm split, native-table extension, repeated require, failed retry, stack balance and original dispatch initialization. Extracted native double/matrix functions pass floating-point bit and matrix-order checks. Rendering, network transport and VGUI interaction are isolated in these tests.
- [x] Modified native TUs passed compilation; client/server build passed. DLL/PDB deployed directly to D:/srceng/hl2sb/bin with four SHA256 matches. No game launch, no commit/push, no resulttxt. Earlier residue-probe edits were retained separately and are not a confirmed residue fix.

#### Remaining migration work

- [ ] Entity/Player/Weapon original extensions: reconcile original DT/NW proxy and callback ownership with the existing native instance tables; validate SetupHands initialization order and remove obsolete player/weapon shims only after their native consumers agree.
- [ ] Widget original module: implement and validate whitelist/output trace behavior and CMoveData:KeyWasDown before removing the current hover workaround.
- [ ] Native render extension helpers, complete original utility/team modules, base variable editor EditValue, sandbox spawn/cleanup contracts and weapon_base animation/AI contracts still require migration. Current original-files count does not include them as complete.
- [ ] Four postprocess paths remain disabled: bokeh_dof needs resolved-depth/NeedsDepthPass support; dof needs a real DOFModeHack consumer; frame_blend needs GetRenderTargetEx/GetMoBlurTex1 and safe native texture initialization; super_dof needs render.Spin. Existing/new native evidence is indexed for reuse.
- [ ] Coordinate lowercase file names with actual include paths and Linux/Android lookup behavior; do not rename VGUI files alone while original vgui_base.lua still names uppercase paths.
- [ ] CEF/HTML/JS, SteamAPI-dependent main-menu/workshop/social paths and Kinect hardware support remain explicitly unsupported or stubbed. Custom local game UI, diagnostics and unrelated campaign/deathmatch content are not wholesale deleted. TTT is outside this migration.
- [ ] Full restart and in-game verification required for Q/C/TAB, text entry, undo, NPC spawning, weapon switching, model/hands and multiplayer net messages. Offline contracts are not a gameplay pass.

### 2026-10-26 Lua 5.4 migration startup regression

- [x] Read the 01:23-01:24 hl2sb session logs. Menu util.lua aborted because Angle was unavailable. Both game realms loaded hook.lua before util.lua, permanently capturing nil type helpers; extension registration and init.lua subsequently failed, including hands initialization and runtime entity class copies.
- [x] Publish Angle alongside QAngle in the native constructor registration. Load util.lua and the original hook module once in native state initialization, before extension scans, with legacy dispatch aliases installed immediately. Remove the two unconditional map-entry hook reloads. Original GMod Lua and installed addons remain unchanged in this repair.
- [x] Offline regression reproduces both old initialization failures and passes the corrected order using the actual util/hook/concommand/table modules, compatibility aliases, original hands Initialize and sky entity Think. Native translation units compile; client/server build passes in 40.705 seconds.
- [x] Directly deployed client/server DLL and matching PDB files to D:/srceng/hl2sb/bin; all four SHA256 hashes match. Evidence: D:/tmp/lua_compare_20261025/deployment_startup_fix_20261026.json and startup_regression_20261026.lua. No game launch, commit, push or resulttxt.
- [x] User confirmed the startup regression is fixed after testing. Broader migration verification remains tracked above.
- [x] Removed the temporary viewmodel residue C++ instrumentation and manual Lua probe at the user's request. Retained unrelated diagnostics and runtime data outside the commit scope.

### 2026-10-26 World tooltip and command dispatch follow-up

- [x] Read the 01:48-01:52 logs. The black world tooltip was its outer border: original cl_worldtips.lua stopped at missing surface.DrawPoly before drawing the pale fill and text. Added the native binding with continuous vertex lookup, strict numeric x/y/u/v fields defaulting to zero, a 4095 vertex cap and the original three-vertex minimum error. Original draw.lua and cl_worldtips.lua remain unchanged.
- [x] Removed server loading of client-owned material proxy scripts, matching the original client bootstrap. The client still loads the material proxy module and scripts.
- [x] Replaced the custom Lua RunConsoleCommand path with native quoted command queuing. It no longer probes concommand.Run or writes ConVars directly, which produced false Unknown command messages for tool mode changes and tool settings after restoring the original concommand module. Registered the native globals in menu and gameplay states. Existing native blocked-command policy remains in effect; special connection handling is outside this follow-up.
- [x] Consulted existing reference indices, captured current matching native functions and archived six functions under D:/tmp/dec/client.dll with index entries. Temporary work: D:/tmp/worldtips_20261026. An older UI analysis project did not match the installed binary; its output was discarded in favor of a fresh project imported from the actual snapshot.
- [x] Native translation units compile. Extracted actual C++ binding tests with the Lua runtime pass polygon defaults, numeric field types, table lookup, limits/errors, command queuing and argument formatting. The unchanged original drawing/world tooltip code completes the background, arrow and multiline text path in that harness. GPU rendering and live engine execution are isolated from this test.
- [x] Client/server build passed in 25.994 seconds. Matching DLL/PDB files deployed directly to D:/srceng/hl2sb/bin and four SHA256 hashes verified. No game launch, commit, push or resulttxt for this follow-up.
- [ ] User verification after full restart: dynamite/lamp world tooltip fill, arrow and text; tool mode/settings changes; absence of the logged DrawPoly and server matproxy errors.

### 2026-10-26 Death and pickup notification fonts/tokens

- [x] Kept original cl_deathnotice.lua, cl_hudpickup.lua, killicon.lua and draw.lua unchanged. Verified the installed HL2MP font file also matches GMod exactly.
- [x] Corrected native font-name resolution: runtime font registry first, gameplay HUD viewport ClientScheme next, with menu state retaining its own scheme. Default menu fonts no longer replace ChatFont or the HL2MP weapon glyphs. Replaced only ChatFont and HL2MPTypeDeath font definitions in resource/clientscheme.res with the current GMod originals, including Verdana sizes/shadow and the 64-pixel icon face.
- [x] Added native surface.DrawText with token lookup shared with text measurement and original optional additive mode. Removed the custom Lua text/token wrapper, which could strip the token marker before native lookup. Existing localization dictionaries remain the source for translated names; unknown tokens retain their marker.
- [x] Fixed duplicate-weapon ammo pickup arguments: use ammo definition names such as Pistol instead of weapon class names such as weapon_pistol. Primary/secondary ammo types produce separate entries; equal types combine actual received counts. Zero amounts and invalid ammo indices are rejected before lookup. Existing game-event transport remains; this change aligns its delivered arguments with the original HUDAmmoPickedUp contract rather than claiming a full transport migration.
- [x] Reused archived ammo notification evidence and archived five current native font/text dependencies under D:/tmp/dec/client.dll. Evidence/tests: D:/tmp/hud_notifications_20261026. Actual C++ font/text bindings plus original notification Lua and real Chinese properties pass font selection, icon face, translated NPC/item/weapon/ammo names, unknown tokens and draw-mode tests. Actual ammo event loop passes separate/combined/invalid/zero cases. Native renderer and network transport are isolated in these tests.
- [x] Changed translation units compile; client/server build passes in 35.532 seconds. DLL/PDB deployed directly to D:/srceng/hl2sb/bin with four SHA256 matches. No game launch, follow-up commit/push or resulttxt.
- [ ] User verification after full restart: grenade/stock weapon kill icons and row spacing, NPC translation, weapon/item/ammo pickup translation, and duplicate-weapon ammo amounts.

### 2026-10-26 Context properties and tooltip follow-up

- [x] Read the 03:15-03:25 logs. No context-click Lua exception is recorded. Kept original properties.lua, contextmenu.lua, DLabel and DTooltip unchanged.
- [x] Found the tooltip color regression caused by the newly corrected HUD font scheme exposing an old custom Default font block: at screen heights1200+, it used a24-pixel additive font. Original DTooltip selects Default and black skin text, which cannot darken the tooltip with additive blending. Replaced the complete Default font block with current GMod's nonadditive Verdana12 definition. The material pixel sampler already has a full-image implementation installed by litexture.cpp; the older low-resolution implementation is overridden and was not treated as the cause.
- [x] Replaced the incorrect MainEyePos=EyePos Lua alias with native MainViewOrigin and MainEyeAngles with native MainViewAngles. Original property selection uses the stable main view, while EyePos can refer to the active offscreen render view. Added native input.IsButtonDown using the input-system state and valid code range, replacing the custom VGUI keyboard/mouse split. Reference functions and direct storage getters were captured from the installed matching GMod binary and archived under D:/tmp/dec/client.dll.
- [x] Offline regression executes the actual C++ main-view/input bindings and unchanged original PropertiesClick/GetHovered path. It reproduces a miss with the old offscreen-view alias, opens the property menu with stable main-view coordinates, and preserves ordinary-UI/non-right-button gates. This is a dependency-level reproduction; the user's actual VGUI click target and live renderer remain unverified.
- [x] Changed C++ translation units compile; client/server build passes in35.437 seconds. Matching DLL/PDB deployed directly with four SHA256 matches, recorded at D:/tmp/context_tooltip_20261026/deployment.json. No game launch, follow-up commit/push or resulttxt.
- [x] User confirmed the context-menu and hover information fixes on2026-10-26 and authorized submission. Broader migration work remains tracked separately.
