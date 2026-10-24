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
