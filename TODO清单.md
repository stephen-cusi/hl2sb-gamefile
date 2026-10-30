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
- [~] base 缺的原版文件：`base.lua`、`dof_node.lua`、`prop_effect.lua`、`ragdoll_motion.lua` 已按 Steam GMod 原版补齐；其余 base 文件仍待核对。
- [~] sandbox 原版效果文件：`balloon_pop.lua`、`entity_remove.lua`、`inflator_magic.lua`、`lasertracer.lua`、`phys_unfreeze.lua`、`wheel_indicator.lua` 已按 Steam GMod 原版补齐；其他效果仍待清点。
- [~] sandbox 编辑实体：`base_edit.lua`、`edit_sky.lua`、`edit_sun.lua`、`edit_fog.lua` 已按 Steam GMod 原版补齐；示例实体仍待清点。
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
- [x] Widget original module: native whitelist/output reuse, TestCollision dispatch and KeyWasDown implemented; original widget.lua restored. Offline original-script interaction passes; live editor acceptance remains below.
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

### 2026-10-26 Bone widget crash and native interaction

- [x] Matched the10:02 full dump to deployed modules. Removed the single-matrix SetupBones output buffer that overwrote the server stack. Parent bone cache now covers vertex bones for followers; invalid indices/model and bone0 are handled.
- [x] Corrected transform callback ordering after ordinary absolute composition; balanced Lua stack, per-entity-chain recursion guard, main-thread gate and component fallback. Added effects transport width and follower/descendant invalidation.
- [x] Restored byte-identical original widget.lua with native trace whitelist/output reuse, TestCollision, KeyWasDown, widget EHANDLE state, BoneLength and client removal lifecycle. Removed superseded widget shims. Seven original widget/property files verified against GMod.
- [x] Actual-body offline regressions pass, including original widget input, nested traces,10000 absent callbacks, errors and parent bone boundaries. Changed TUs compile; scoped header rebuild succeeded in24.614s. Direct client/server DLL+PDB deployed and four SHA256 pairs verified.
- [x] Reused reverse indices and archived the two missing current native callback bodies. Evidence, exact source/reverse locations, tests and deployment: D:/tmp/widget_review_20261026/REVIEW.md. No game launch, commit/push or resulttxt.
- [ ] User full restart and live acceptance: immediate bone points without moving the NPC, correct animated positions, click/release opens axes, move/rotate/scale, removal and map reload. Offline fixture isolates engine broadphase/rendering and does not verify this step.


### 2026-10-26 Prop context properties: fire and missing options

- [x] Read current session logs and original property filters. Remove already works and is outside the defect scope. Reused GLM's unarchived matching server functions, checked the existing evidence index, and archived the captures with version hashes. Captured the missing current client class getter with Ghidra.
- [x] Native physics props now retain their canonical client map class independently of the inherited prediction datamap. This makes the unchanged original Keep Upright and Gravity exact-class filters work. Data-less server props keep their original identity instead of a temporary override conversion. Model/state/permission restrictions remain in the original Lua.
- [x] Removed the obsolete flammable-propdata gate from native prop Ignite. Both Entity and Animating bindings now require duration, accept optional radius, and pass the reference NPC-only/designer flags. Failed flame creation cannot dereference a missing light-effect entity.
- [x] Seven property/module Lua files are byte-identical to the installed GMod originals and were not edited. Actual native constructor/class getter reproduces the old missing-option path and restores original menu filters. Extracted actual fire bindings, base fire implementation and prop override pass original Ignite/Extinguish receive callbacks for100 cycles, radius/default/required-argument cases, NPC ignition veto and failed flame creation. Renderer, transport and physics services are isolated in this offline test.
- [x] All four modified C++ translation units compile successfully.
- [x] Final client/server build succeeded in39.082s; client/server DLL and matching PDB directly deployed to D:/srceng/hl2sb/bin with four SHA256 matches.
- [ ] User live verification after full restart: ordinary and no-propdata props offer Keep Upright/Gravity, ignition shows fire and switches to Extinguish, toggles/Keep Upright act correctly, and existing Remove remains usable. No game launch, commit/push or resulttxt in this round.

Evidence: D:/tmp/context_properties_fix_20261026.


### 2026-10-26 Context properties live regression: cursor, fire and upright

- [x] Read the22:44-22:47 session logs first. Keep Upright fails at original keep_upright.lua:41 because native PhysObj:GetAngles is absent. Previous menu-filter tests did not exercise the full constraint creation or the real native extinguish body.
- [x] Added native PhysObj:GetAngles with one Angle return, using GetPosition(NULL,angles), and retained original property/constraint Lua unchanged. Full original constraint.lua and Keep Upright Receive paths complete25 create/remove cycles with angle/body/limit assignment and cleanup state in an isolated native-services fixture. Actual physics solver behavior remains a live check.
- [x] Replaced the inherited inline Extinguish flag-only implementation with the native flame-removal lifecycle: remove attached flame, clear its effect handle and clear FL_ONFIRE. Existing virtual slot is unchanged. The original Ignite/Extinguish Receive callbacks now exercise the extracted real Extinguish implementation for100 cycles and verify all created flame objects are removed, including sound/lifecycle service boundaries.
- [x] Current GMod CAI_BaseNPC/CNPC_Citizen/CNPC_CombineS vtables share AllowedToIgnite=true; corrected our base default from false to true. Explicit subtype overrides and the existing virtual ignition gate remain. Added four current server functions to the archive/index. An older named Ghidra project did not match current bytes and was discarded; the actual copied binary was imported fresh.
- [x] Unified native property-click and world-hover rays with the same screen projection and stable player view. Removed the click-only extra aspect-ratio FOV scaling; offscreen renders no longer change the world-hover projection. Actual native input callback plus original PropertiesClick/GetHovered and Keep Upright/Gravity filters opens the correct menu away from the center crosshair in the regression fixture; ordinary UI/capture/non-right-button gates remain.
- [x] Modified C++ translation units compile. Removed628 stale consuming game objects for the two changed server headers using include closure and mtime, preserving engine/library outputs. Client/server build succeeded in2m22.183s. No class layout or virtual-slot changes.
- [x] Matching client/server DLL and PDB directly deployed to D:/srceng/hl2sb/bin with four SHA256 pairs verified.
- [ ] User live verification after full restart: hover/right-click away from crosshair, ignite/extinguish ordinary props and citizens/NPCs, Keep Upright create/remove and actual physical response. Offline tests isolate VGUI hit testing, network transport, renderer and solver; they are not a live gameplay pass.

Evidence: D:/tmp/context_properties_round2_20261026. Original Lua unchanged. No game launch, commit/push or resulttxt.


### 2026-10-27 Removal crash and entity-drive follow-up

- [x] User confirms extinguishing now works. Read the23:14 session and matching crash dump: service-side PlayerThink dereferenced null game rules, with entity_remove targeting index0. Deployed fault instructions match the dump. Original GMod excludes world from IsValid and protects world/player/core entities from Lua Remove; corrected these native contracts instead of adding a crash-site null guard. Original properties/remove.lua remains unchanged.
- [x] Separated MoveData move angles from entity angles. Movement hooks now preserve script edits to move data instead of overwriting them from an unchanged command snapshot; only SetupMove receives a user command. FinishMove takeover retains previous-predicted-origin bookkeeping.
- [x] Local driven entities now enter the existing prediction history and release only prediction owned by the drive state. Target changes and controller removal clean up that ownership. Removing a driven entity/player stops the drive while its handles are still valid.
- [x] Routed entity-driving animation to the original GM:PlayerDriveAnimate. Native Player:SetRenderAngles/GetRenderAngles now use animation-owned orientation on both realms; server no longer falls through to the legacy absolute-angle shim. The server accessor is nonvirtual; no layout or vtable change.
- [x] Changed translation units compile. Cleared41 stale game objects consuming the server HL2MP header, then client/server build succeeded in26.787s. Client/server DLL and PDB directly deployed to D:/srceng/hl2sb/bin; four SHA256 pairs match deployment.json.
- [x] Stopped adding/running native tests when the user requested immediate deployment. Original-Lua/native dependency checks already completed before that request; they do not establish live VGUI, rendering, network or physics acceptance.
- [ ] User full restart and verification: remove ordinary/Keep Upright props, right-click empty world, drive forward/up/rotate/zoom, E exit, remove driven target, death/respawn and visible remote-control pose. The reported remote camera distance and jitter still require live confirmation.

Evidence: D:/tmp/remove_drive_20261026. No game launch, commit/push or resulttxt.


### 2026-10-27 Native extension migration: Util and Render

- [x] Restored byte-identical installed GMod extensions/util.lua and extensions/client/render.lua. Platform-specific binary-module paths remain separately in hl2sb/compat/binary_modules.lua; original player_auth owns GetUserGroups.
- [x] Corrected native TableToKeyValues root handling, scalar conversion, recursive-table rejection, escape propagation and error cleanup. Added native ordered Key/Value conversion, case preservation independent of the engine key symbol pool, duplicate-key handling and TimerCycle in milliseconds. Existing UI-only converters remain separate.
- [x] Added native global GetRenderTarget with the reference format/depth/flags and no-value failure path. Added render.DrawBox using native oriented mesh utilities/current material and hardware-backed SupportsPixelShaders_2_0. The current-target render.GetRenderTarget remains distinct.
- [x] Reused existing render-target evidence and archived ten newly captured current GMod functions with index entries. Native TUs compile; client/server build succeeded in23.461s. Directly deployed DLL/PDB to D:/srceng/hl2sb/bin with four SHA256 matches. No headers changed, so no object cleanup was needed.
- [x] Stopped additional native tests on user instruction and deployed immediately. Earlier dependency checks are not live renderer/network/engine validation.
- [ ] User full restart and live test: menu/spawnlists, saving/loading KeyValues-backed settings, tool screen/render targets, widget boxes and ordinary HUD/material drawing.
- [ ] Entity/Player/Weapon extensions and TTT team/observer contracts remain pending. Their original-file replacement requires native instance/data-table/lifecycle work; this batch does not mark them complete.

Evidence: D:/tmp/native_extensions_20261027. No game launch, commit/push or resulttxt.


### 2026-10-27 Original Entity helpers and Sandbox counters

- [x] User confirmed the Util/Render batch works. Submitted only that batch as engine614106f6 and contentfb403e6; unrelated viewmodel edits, runtime data and thirdparty remain outside the commits. No push.
- [x] Restored the unchanged Entity helper section from current GMod at hl2sb/original/entity_helpers.lua: GetVar/SetVar, creator/constraint helpers, removal callbacks and PhysWake. The original section uses the actual instance table and forwards callback arguments; removed the private native GetVar/SetVar accessors and the old weak-table callback shim. Existing obsolete private-variable lookup helpers remain for the separate metatable migration; no new values are written there by these APIs.
- [x] Added native ProtectedCall with required function, trailing argument forwarding, error reporting, discarded callback results and one success boolean. Current GMod body captured with Ghidra and archived/indexed. This is also used by original duplicator code.
- [x] Restored byte-identical current Sandbox player_extension.lua, including original removal-count callback arguments and same-tick limit-notification deduplication. Existing engine TickCount is available in both realms.
- [x] Changed native TUs compile; client/server build succeeded in19.900s. Matching DLL/PDB directly deployed to D:/srceng/hl2sb/bin and four SHA256 pairs verified. No headers changed and no object cleanup needed. No native tests run for this batch, per user instruction.
- [ ] User full restart/live test: spawn/delete/undo props and constraints, watch object counts fall on removal, cleanup, duplicator copy/paste and addon removal callbacks.
- [ ] Full Entity data tables, metatable ownership, Player/Weapon extensions and TTT team/observer contracts remain pending. This batch restores original helper behavior, not all Entity extensions.

Evidence: D:/tmp/entity_helpers_20261027. No game launch, second-batch commit/push or resulttxt.


### 2026-10-27 World tooltip line overlap

- [x] User narrowed this round to text overlap; balloon/TNT investigation stopped without changes. Deferred the three independent content migrations and restored only those own edits from hash-verified pre-edit snapshots.
- [x] Original draw.DrawText expects adjacent empty matches from string.gmatch to advance lines. Lua5.4 suppressed those matches. Captured actual installed GMod string iterator with Ghidra, archived/indexed it, and restored its empty-match progression in lua/src/lstrlib.c. Original draw/worldtip Lua unchanged.
- [x] Single TU compilation and lua_shared build succeeded. Directly deployed lua_shared.dll and matching PDB to D:/srceng/bin with SHA256 verification. No headers changed, native tests, game launch, commit/push or resulttxt.
- [ ] Full restart and user verification of multiline TNT/other world tooltips. Balloon/TNT behavior remains unresolved and outside this repair.


### 2026-10-27 Original stock content and logical-entity validity

- [x] Read the latest 02:35-02:52 session logs before editing. Two Lua failures were recorded: Keep Upright asserted that its constraint system was valid, and the wheel tool indexed a boolean returned by constraint.Motor. No fresh hook iteration exception appeared in this session. Sound precache and a missing env_explosion kill icon warning remain separate observations.
- [x] Restored byte-identical installed GMod lua/autorun/game_hl2.lua, weapon_fists.lua at the existing shared.lua loader path, and Sandbox camera_flash.lua at the existing effect loader path. Current spawnmenu consumes list Weapon directly, and the required damage, force-scale and dynamic-light APIs are present. Original Lua unchanged.
- [x] Corrected native server Entity:IsValid and Remove to compare with the actual world entity instead of rejecting every entity with edict index zero. CLogicalEntity has no network edict, so the old test rejected phys_constraintsystem and phys_hinge, causing both recorded constraint failures. Client handling remains unchanged. Original constraint/tool Lua unchanged.
- [x] Reused archived current IsValid and removal bodies. Captured and archived current IsWorld separately to verify its distinct contract; retained its existing index-based behavior rather than conflating it with IsValid. No public headers changed.
- [x] Single TU compilation passed; client/server build succeeded in33.308s. Directly deployed matching DLL/PDB to D:/srceng/hl2sb/bin and verified four SHA256 pairs. No native tests, game launch, commit/push or resulttxt.
- [ ] User full restart/live verification: stock spawnmenu weapons/items, fist draw/attack/combo/holster, camera effects, Keep Upright create/remove/undo and wheel attachment/control. Native source review and compilation do not establish live physics/rendering acceptance.
- [ ] Balloon/TNT repair remains paused by user instruction. Full Entity/Player/Weapon extensions and TTT remain tracked as pending; this batch does not complete those migrations.

Evidence: D:/tmp/original_content_resume_20261027.


### 2026-10-27 Original Player extension and migration inventory

- [x] Read the latest 03:03-03:13 session logs first. No Lua traceback/assertion/type error is recorded; the prior constraint-system and wheel errors did not recur. User confirms balloon rope/attachment and delayed/key-triggered TNT now work. The shared IsValid correction explains why native logical constraints were previously rejected; the TNT causal chain was not separately captured.
- [x] Restored byte-identical installed lua/includes/extensions/player.lua. Removed the custom pcall-based engine lookup, guarded table lookup, reordered SetupHands and obsolete method fallbacks. Native StripWeapons/Kill/Spectate/drive bindings already exist and remain authoritative; original client Player extension is unchanged.
- [x] Native startup now publishes missing public CBaseAnimating methods onto Player while preserving its own methods and metamethods. Original Player lookup can reach animation APIs without calling the legacy native __index first. Entity:GetTable accepts nil/stale entities with no values, validates the entity family before handle access, and retains the actual per-instance table for live entities.
- [x] Apply scripted anim type defaults once, before script setup; do not replace state configured between Create and Spawn. This preserves the original SetupHands order (DoSetup then Spawn), including viewmodel parenting/MOVETYPE_NONE. Reused the archived native GetTable, StripWeapons and scripted Spawn evidence; no new binary behavior was inferred from method names.
- [x] Three changed translation units compile; client/server final build succeeded in20.006s. Matching DLL/PDB directly deployed to D:/srceng/hl2sb/bin with four SHA256 pairs verified. No public headers changed, no object cleanup/native tests/game launch/commit/push/resulttxt.
- [x] Created D:/srceng/GMod迁移清单.md with current original-file comparisons, moved-path mappings, completed batches, pending native contracts, deferred CEF/Steam APIs and live verification limits. Full Entity/DT, Weapon legacy base and TTT remain incomplete.
- [ ] User full restart/live verification: hands visible after spawn/respawn, normal weapon/animation/model methods, custom Player fields, context/player model UI, freeze/godmode and ordinary prop/constraint creation/removal/undo.
- [ ] Remaining log warnings tracked separately: base_anim fallback registration, debug shaders, transient SkyPaint proxy registration and gmod_dynamite kill icon. They are not marked fixed or treated as Lua exceptions.

Evidence: D:/tmp/player_extension_migration_20261027.


### 2026-10-27 Native generic-for traversal compatibility

- [x] User reports the Player batch appears normal. Read fresh03:35-03:36 logs: one client invalid-key error from next inside original hook.lua:95. The exact hook name/callback/table mutation is not captured by this traceback; no claim that a particular addon caused it.
- [x] Reused the current matching GMod Lua runtime project and captured public lua_next, internal table traversal and VM native-next preparation. They preserve invalid-key errors for public next while specialized native loops track a private slot cursor. Captures archived/indexed with installed binary SHA256.
- [x] User pointed to opglua. Read D:/tmp/glua/glua-src/src/lj_tab.c, lj_parse.c, vm_x64.dasc, vm_arm64.dasc and lib_base.c; their native iterator/table/nil-control check and positional scan agree with the binary. Reference tree remains read-only.
- [x] Adapted the existing Lua5.4 interpreter: one/two-result native next loops starting with nil control and no close object use a private per-loop cursor. Callback removal/rehashing no longer requires finding the previous key again. Ordinary next, pairs return identity, custom iterators, nonnil starting keys and real close objects retain the existing call path. This does not promise stable/exhaustive traversal when arbitrary insertions rehash a table, nor identical LuaJIT hash order.
- [x] Original hook.lua content matches except line endings; Player extension matches byte-for-byte. Neither Lua file was edited. No snapshot/pcall wrapper, global invalid-key suppression, table-layout change or header modification.
- [x] Changed C translation units compile; lua_shared build succeeded in3.584s. Direct DLL/PDB deployment to D:/srceng/bin; both SHA256 pairs match. No native tests, game launch, commit/push or resulttxt. This is a runtime prerequisite batch; Weapon/Entity/TTT migration remains pending.
- [ ] User full restart/live verification: map entry and reload, hands/weapon change, hook-driven addon and menu behavior; confirm the reported invalid-key traceback does not recur. Compilation is not a live reproduction or acceptance result.

Evidence: D:/tmp/next_iteration_20261027. opglua sources referenced read-only and recorded by path/hash.


### 2026-10-27 Original Weapon extension and registry migration

- [x] Read latest03:52-03:56 logs first. No Lua exception or invalid-next traceback is recorded; user also reports the iteration error appears gone. Existing shader/base_anim/SkyPaint warnings remain separate and are not marked fixed.
- [x] Restored byte-identical installed includes/extensions/weapon.lua. Native animation methods are published onto Weapon while preserving its own methods/metamethods, using the same inheritance bridge already verified for Player. Removed the old server-only WeaponSound Lua override; native WeaponSound already has prediction/owner recipient filtering and the correct optional sound-time argument.
- [x] Native weapon loading now creates fresh class definitions with Primary/Secondary tables and metadata; it does not copy default base methods over a derived class before its declared Base can be resolved. Registration and instance binding use unchanged original weapons.Register/Get/GetStored. Native factories are created only when GetStored contains the exact definition, including registration vetoes and ClassNameOverride.
- [x] The post-load native callback now invokes both original scripted_ents.OnLoaded and weapons.OnLoaded, allowing original baseclass.Set to populate weapon base tables. It previously only called the entity module despite its comment naming both.
- [x] Retired five obsolete Lua files: the singular weapon module, its sync shim, and the three old weapon_hl2mpbase_scriptedweapon scripts. Removed the shim include. No installed addon Lua references to these old APIs/base names were found. Native C++ factory/class remains; only the obsolete Lua implementation was removed.
- [x] Weapon/Entity aliases are seeded on the instance before setup; removed duplicate early SetupDataTables dispatch. The existing accessor factory is installed before the single remaining setup call and Initialize follows it. This does not complete original InstallDataTable/typed-DT migration; the customized weapon_base remains a separate pending batch.
- [x] Reused archived native WeaponSound and SetupDataTables evidence; original weapons/Weapon Lua directly specifies registration, inheritance and lookup contracts. No new binary-function implementation was introduced and no headers changed. Source snapshots/reference hashes/diffs and logs are retained in this batch evidence directory.
- [x] Three changed translation units compile; final client/server build succeeded in19.744s. DLL/PDB directly deployed to D:/srceng/hl2sb/bin; four SHA256 pairs match. No native tests, game launch, commit/push or resulttxt.
- [ ] User full restart/live verification: spawnmenu weapon categories and giving weapons, fists/toolgun/camera, addon primary/secondary/reload/holster, draw/sound/owner fields, declared base methods and camera/network variables. Compilation and static dependency checks do not establish live prediction/network/render acceptance.

Evidence: D:/tmp/weapon_registry_migration_20261027. Migration inventory updated at D:/srceng/GMod迁移清单.md.


### 2026-10-27 Original weapon UI/AI mapping and texture shim removal

- [x] Previous migration submission completed: engine10f42bd25 and content731b4e9 pushed to box-experiment. Other-session viewmodel/finger panels and runtime/addon files were excluded. Those commits also include the earlier approved Util/Render batch in pushed history.
- [x] Read the latest logs first; no recorded Lua exception or invalid-next error. Existing base_anim/shader/SkyPaint warnings remain separate. Latest Weapon registry batch has not been claimed fully live-verified merely because the logs are quiet.
- [x] Restored byte-identical current weapon_base/cl_init.lua and ai_translations.lua. This removes custom material-icon/pcall fallbacks, restores original translated Purpose/Instructions and passes world-model draw flags. All123 ACT names used by original AI mapping are registered by the native activity enum provider. AI file restoration alone does not prove native NPC weapon behavior is complete.
- [x] Added native surface.GetTextureID using DrawGetTextureId first, create/bind only on miss, with original binding flags; surface.SetTexture is native. Reused indexed surface.GetTextureID.c and surface.SetTexture.c rather than repeating prior captures.
- [x] Removed the gmod_surface.lua texture lookup wrapper, SetTexture alias and private __textureNames cache. Native weapon-selection numeric icons now use the real surface texture dictionary. String/Material icon paths remain in the existing HUD integration. Other surface shims remain pending and were not silently marked migrated.
- [x] Two changed C++ translation units compile; final client/server build succeeded in22.659s. Matching DLL/PDB directly deployed to D:/srceng/hl2sb/bin with four SHA256 matches. No public headers changed, native tests, game launch, commit/push or resulttxt this batch.
- [ ] User full restart/live verification: weapon selection icons and information bubble, translated Purpose/Instructions, tool-screen textures, menus after map reload and weapon world-model rendering. Original GetTextureID caches through the native dictionary; actual renderer and level lifecycle require live confirmation.
- [ ] weapon_base/shared.lua, sh_anim.lua and server init.lua remain pending. Server NPC burst/rest custom callbacks and their native readers need separate behavior verification before removing those Lua adapters. DT/NetworkVar and CallOnClient are also still pending.

Evidence: D:/tmp/weapon_ui_migration_20261027. Local migration list updated at D:/srceng/GMod迁移清单.md.


### 2026-10-27 Original weapon server base and NPC result contracts

- [x] Checked latest logs before changes; no Lua traceback, invalid-key, assertion or bad-argument errors recorded. No live acceptance inferred beyond the user's prior reports.
- [x] Restored byte-identical installed weapon_base/init.lua. Deleted its added GetNPCBurstSettings/GetNPCRestTimes adapters, redundant capability fallbacks and flat legacy defaults. Native capability enums and capitalized weapon-info readers already exist. Original accessors remain exactly as supplied.
- [x] Located current CWeaponSWEP RTTI primary vtable and slots340-344, captured the five native getters and grouped burst/rest helpers with Ghidra. Native behavior accepts the whole numeric group, otherwise uses burst1/1/base fire rate and rest0.3/0.6. Removed per-field success/clamps from our readers and preserve the caller's full Lua stack on all outcomes. No destructive lua_pop(gettop) remains in these five methods.
- [x] Archived/indexed all seven functions with installed server binary hash under D:/tmp/dec/server.dll. Old unrelated version-specific callback-name mappings were not used as current address evidence. Reference raw slots and bodies retained in this batch directory.
- [x] Changed translation unit compiles; client/server build succeeded in46.933s. DLL/PDB directly deployed to D:/srceng/hl2sb/bin, four SHA256 pairs match. Previous weapon UI/texture changes are retained. No headers/layout/virtual slots changed and no object cleanup required.
- [x] Checked compat/includes/base tree for replacement NPC wrapper definitions; none remain. Original init.lua is unchanged. No native tests, game launch, commit/push or resulttxt.
- [ ] User full restart/live test: NPC-equipped addon weapons, firing bursts and rest timing, custom numeric callbacks and ordinary player weapons. The actual NPC regulator/network/prediction behavior remains unverified in-game.
- [ ] weapon_base/shared.lua and sh_anim.lua, hold-type storage, complete Entity/typed DT and CallOnClient remain pending. This batch does not claim complete SWEP parity.

Evidence: D:/tmp/weapon_npc_migration_20261027. Migration list updated at D:/srceng/GMod迁移清单.md.


### 2026-10-27 Original hold-type mapping and native state

- [x] Read fresh07:51-07:53 logs first: no Lua exception recorded. User explicitly says NPC firing is not smooth and later clarifies only native weapons are installed/tested. This is NOT accepted as a passing NPC cadence test and is not attributable to the prior scripted-weapon callbacks. Native AI shot-regulator/cadence remains an unresolved report.
- [x] Restored byte-identical original weapon_base/sh_anim.lua. Removed custom HoldType family/fallback/m_acttable builders and Lua SetHoldType/GetHoldType from the still-partial shared.lua. Original AI/player activity maps now own translation. No compat/includes hold-type shadowing definitions remain.
- [x] Reused archived binding and captured current native scripted setter, constructor, application/copy helper and change-detection fragment. Scripted setter ignores empty names, retains the original case and80-byte bounded storage; application dispatches original SetWeaponHoldType on state change. Base/SMG1 native slot380 is empty; retained that stock behavior instead of inventing a native-weapon pose setter. New captures are archived/indexed with installed server SHA256.
- [x] Added native scripted hold-type network string and nonvirtual accessors; client/server update original mapping on initialization and before active/animation work. GetHoldType reads native state rather than a mutable class field. No virtual slot inserted. Per-instance update guard prevents mapping recursion. Native weapons retain their existing activity-based getter and empty setter.
- [x] Changed C++ translation units compile. Header consumer closure contains9 source files; removed10 stale game objects by mtime, preserving unrelated engine/library outputs. Client/server final build succeeded in21.731s. Direct DLL/PDB deployment to hl2sb/bin verified four SHA256 pairs. No native tests, game launch, commit/push or resulttxt.
- [ ] User full restart/live verification: toolgun/fists/camera and addon hold types in third person, idle/walk/crouch/jump/swim/fire/reload, late-joining remote players and runtime hold-type changes. Native solver/network/render acceptance not established by compilation.
- [ ] Native NPC firing continuity remains pending. Full shared.lua replacement, DT/NetworkVar, CallOnClient, TTT and entity registry migration remain pending. This batch does not claim to fix native NPC shooting.

Evidence: D:/tmp/weapon_holdtype_migration_20261027; scoped cleanup and deployment manifests included.

- [x] Final original-file dependency audit found ACT_MP_SWIM_IDLE absent. Reused NativeEnumerations.Current20261026.c for the reference name; added native name-based private activity registration without shifting the fork's shared enum IDs. All35 names in original sh_anim.lua now have native providers. Its numeric ID is fork-specific, so exact numeric GMod activity-ID parity is not claimed. Added lsrcinit.cpp single-TU compilation, rebuilt and redeployed final DLL/PDB with four verified hashes (21.731s).


## 2026-10-27 持枪动画与自定义世界模型回归修复

- 修复上轮原版 sh_anim.lua 迁移遗漏的枚举算术前提：19 个持枪家族按 idle/walk/run/crouch/crouchwalk/attack/reload/jump/swim idle/swim 连续排列；删除只覆盖普通姿态的临时结果转换。保留全部 273 个活动名称和 Portal 之后的枚举编号。原版 sh_anim.lua、插件 Lua 均未改。
- Entity 和 Animating 两个 DrawModel 绑定现在让脚本武器走虚绘制入口及原版 DrawWorldModel；嵌套 self:DrawModel 由已有绘制作用域回落模型，避免绕过 WElements。复用已归档的原生 Entity.DrawModel 行为，并核对当前安装版 C_WeaponSWEP 绘制入口。
- 删除初始化/装备时引擎往实例表写 Owner 的旧代码。原版 Weapon.__index 的 Owner 回退现在由原生 Entity.GetOwner 按实际武器持有者回答；插件明确写入的字段保留。动画事件接收者改为武器 userdata。
- 客户端 SetPos/SetAngles 使用原生父子感知的绝对变换，GetAngles 返回绝对角度；移除直接相减欧拉角的错误路径。相关 GetOwner/SetPos/SetAngles/GetAngles 及绘制参考已归档到 D:/tmp/dec/client.dll，并更新 index。
- ai_activity.h 按包含闭包和 mtime 精确清理 1212 个 game 对象，未全清 build，未删除引擎/库对象；逐项回验这些对象已重编。随后源文件改动仅做增量构建。单 TU 编译及 client/server 构建通过，DLL/PDB 直接部署并核对四对 SHA256，见 deployment.json。
- 未启动游戏、未运行 native test、未提交推送、未生成 resulttxt。可视结果待用户完整重启后验证：AWP 落地与镜子/第三人称的自定义世界模型、工具枪蹲伏、各持枪姿态。编译和静态核对不代表游戏内显示已确认。原生 NPC 射击连续性仍是独立未解决项。

证据：D:/tmp/weapon_animation_regression_20261027。


## 2026-10-27 AWP 世界模型零体积修复

- 用户确认姿态修复有效，但 AWP 世界模型仍只有影子。本次日志无相关 Lua 异常。
- 定位到原生 Matrix 绑定：Matrix() 默认零矩阵，Scale 只返回新矩阵而不修改 self。插件原样执行 Matrix():Scale 后把原矩阵交给 RenderMultiply，可见骨骼基向量全部归零。
- 核对当前 GMod 原生构造器/Scale 与三层数学辅助函数：无参数/nil 构造单位矩阵；Scale 原地后乘缩放矩阵，零返回。修正 public/lua/mathlib/lvmatrix.cpp 两处，插件和原版 Lua 零改动，无头文件修改、无对象清理。
- 单 TU 和 client/server 增量构建通过，直接复制 DLL/PDB 并核对四对 SHA256，见 D:/tmp/awp_matrix_20261027/deployment.json。未启动游戏、未运行 native test、未提交推送；实际世界显示待用户完整重启复测。


## 2026-10-27 AWP 自定义世界模型与物理位置脱节

- 用户确认模型已可见，但物理枪拖动时只有影子移动，释放后才重新对齐；攻击也看不到模型弹飞。
- 新日志无对应 Lua 异常。插件 DrawWorldModel 通过武器 GetBoneMatrix 读右手世界位置；隐藏基础模型后，旧绘制入口不再保证基础模型骨骼刷新。GetBoneMatrix 按已归档原生行为仅读取缓存，不能改成全局强制 SetupBones。
- 在客户端脚本武器外层 DrawWorldModel 回调前调用已有 SetupBones，保持嵌套模型绘制回落和原版插件不变。只改 c_basecombatweapon.cpp，无头文件变化、无对象清理。单 TU 和增量构建通过，直接部署 DLL/PDB 并核四对 SHA256。
- 未启动游戏、未运行 native test、未提交推送。待用户完整重启验证拖动/旋转/受击时的模型同步；现有服务端武器 TraceAttack/OnTakeDamage/VPhysicsTakeDamage 施力链保留，不能仅凭视觉停留判断物理力没执行。日志另有零伤害力提示，尚无触发武器或实体关联证据，本轮不猜测修改全局施力逻辑。
- 参考核查已归档并更新 index，证据 D:/tmp/awp_physics_follow_20261027。


## 2026-10-27 原版 util 入口与共享查询

- 开始前读取新版 agentmd 与 redll/README.txt。redll 默认旧参考路径和工程与实际 Steam 二进制不同；本批保留其提取/归档流程，通过明确配置复用已匹配当前 Steam client 的 current_client 工程。最初手工提取的已有结果直接归档，没有再重复提取。
- 最新 09:54 至 09:56 日志无 Lua traceback；仍有电棍声音未预缓存、零伤害力等独立警告，本批未猜测修复。
- lua/includes/util.lua 整文件恢复实际 GMod 原版，逐字节哈希一致。engine.GetGames 的客户端已有本地挂载枚举移至共享原生实现，并补服务端注册，移除原版 IsMounted 外面的缺函数兜底。
- player.GetByID 双端原生注册，按实体索引查询；当前客户端函数/实体列表辅助函数和服务端绑定/玩家索引链已核对。删除 util.lua 与 gmod_globals.lua 两份旧包装。原版 player.GetBySteamID 等保持原样。
- GetGames 只枚举现有支持的八种本地内容挂载，不宣称完整 Steam depot/账号系统。installed 表示发现本地挂载，owned 返回 false，表示未查询账号所有权；mounted 独立取本地挂载状态。原版 IsMounted 只消费 mounted。完整 depot 管理与在线所有权暂缓。
- 未改头文件，不清 .o。四个 cpp 的单 TU 编译通过，client/server 构建 23.112 秒；直接部署 DLL/PDB，四对 SHA256 通过。未启动游戏、未运行 native test、未提交推送、未生成 resulttxt。其他会话及运行数据未动。
- 证据：D:/tmp/util_entry_migration_20261027；新取证位于 D:/tmp/redll/client.dll 和 server.dll，已更新索引与语义说明。旧 D:/tmp/dec 已不存在，不再引用它作为当前归档位置。
- 原生 NPC 射击连续性仍独立待查。本批不是该问题的修复。
- 用户新增交付要求：以后每批附快速验证步骤、可粘贴命令及预期结果。

本批快速验证：完整退出后重启，进入本地地图，在控制台逐行执行。

```text
lua_run print(IsMounted("hl2"), IsMounted(220), IsMounted("__missing__"))
lua_run_cl print(IsMounted("hl2"), IsMounted(220), IsMounted("__missing__"))
lua_run local p=player.GetAll()[1] print(player.GetByID(p:EntIndex())==p, IsValid(player.GetByID(0)), IsValid(player.GetByID(99999)))
lua_run_cl print(player.GetByID(LocalPlayer():EntIndex())==LocalPlayer(), IsValid(player.GetByID(0)), IsValid(player.GetByID(99999)))
```

预期前两行均 true true false，后两行均 true false false，无 Lua 报错。若客户端命令提示 sv_allowcslua 为 0，在本地测试服务器设 sv_allowcslua 1 后重试。再快速检查 Q 菜单的原生 NPC、武器列表和生成；不要把控制台查询成功当作全部挂载资源/玩法已经验证。


## 2026-10-27 Wiki 与当前原生挂载层修正

- 本轮先复查原始 Wiki 快照、上轮 GetGames/GetByID 取证和当前日志。最近日志仍为 09:54-09:56，无新 Lua traceback；没有据此声称真实游戏行为已通过。
- 通过新版 redll.py 首次导入实际 Steam filesystem_stdio.dll 的哈希匹配副本，归档构造器、Steam 安装路径查询、订阅/安装状态初始化、正常与 fallback 挂载及配置保存九个函数。已回填语义和索引。首次直接导入路径含括号使批处理失败，改用外部证据目录的同哈希副本，不改 Steam 原文件。
- 替换八项旧目录表，按当前原生构造器保留完整 31 项清单、标题、应用编号与额外内容目录。HL2/Episodes 为一个条目；不再人为多列 episodic/ep2/lostcoast。原版 IsMounted 的名称别名保持原样。
- GetGames 现在只读查询。游戏浏览 PathID 在启动和 Lua filesystem 增删 GAME 挂载时刷新，查询不再调用 AddSearchPath。注册浏览 PathID 时设置 request-only，移除已取消的旧别名，并去重。未改变第三方 addons 内容。
- 路径判断不再按任意子串命中：排除 addons/download/workshop；普通内容按精确目录和 gameinfo 识别，DLC/额外目录验证同级主游戏目录；sourceengine fallback 只认完整 content_<folder>.vpk 或 content_<folder>_dir.vpk 名称。两个 Insurgency 条目借 gameinfo 的 app ID 消除同目录歧义，无法证明身份则不报已识别。
- installed 与 mounted 分离：本地安装目录即使未挂载也可报告 installed。现有 Steam 上下文可用的构建按当前原生链查询 owned=BIsSubscribedApp、installed=owned&&BIsAppInstalled&&非空GetAppInstallDir，挂载结果再受这两个状态约束。本机 DISABLE_STEAM=1，因此 owned 仍按用户允许的外部能力边界返回 false 占位；本地 mounted 独立反映内容可用性。该独立运行模式与 GMod 账号完整模式存在明确边界，不宣称所有权或 Steam 库扫描已实现。Steam-enabled 分支未运行验证。
- GetByID 复用上一批当前客户端/服务端绑定及辅助查找证据，不重复逆向、不加 Wiki 未证明的 +1 或 UserID 转换；现实现保持玩家槽位查找与 NULL 失败结果。Wiki connectionID 一词不作为改变已证实二进制行为的依据，真实连接事件编号关系不作未经实测的保证。
- 仅修改 lsrcinit.cpp、mountaddons.cpp、lfilesystem.cpp，无头文件改动，不清 .o。三个 cpp 单 TU 通过；最终 client/server 构建 20.502 秒。直接部署 client/server DLL/PDB 并记录四对 SHA256。未启动游戏、未运行 native test、未提交推送、未生成 resulttxt。
- 证据 D:/tmp/getgames_wiki_fix_20261027；归档 D:/tmp/redll/filesystem_stdio.dll/_index.txt。原版 util.lua 与其他原版/插件 Lua 本轮均未改动。NPC 原生射击节奏仍是独立未解决项。

快速验证：完整退出重启后进入本地地图，控制台执行：

```text
lua_run print(#engine.GetGames(), IsMounted("hl2"), IsMounted("ep2"), IsMounted("__missing__"))
lua_run_cl print(#engine.GetGames(), IsMounted("hl2"), IsMounted("ep2"), IsMounted("__missing__"))
lua_run_cl local p=LocalPlayer() print(player.GetByID(p:EntIndex())==p, IsValid(player.GetByID(0)), IsValid(player.GetByID(99999)))
```

本机挂载不变时，前两行应为 31 true true false，后一行 true false false。再到 Q 菜单的游戏分类打开 HL2，确认模型列表可浏览、图标仍能生成。字段排查可用 lua_run PrintTable(engine.GetGames())；当前无 Steam 模式 owned=false 不代表已确认用户未购买。


## 2026-10-27 Entity DT 原生槽与原版安装器

- 本批完成 DT 数据链，不宣称完整 Entity 拓展或完整 weapon_base/shared.lua 已原版化。后者仍有 LastShootTime、CallOnClient 和其他旧基类内容待迁移。
- 联网已核对冒号路径 Entity:NetworkVar、SetDTFloat、GetDTFloat、NetworkVarNotify、ENTITY:SetupDataTables。最初点号页面 404 已纠正。VDC 的 Prediction/Networking_Entities 返回 Anubis 验证页，未当作已读资料；另取 ValveSoftware/source-sdk-2013 官方 c_baseentity.cpp 与 dt_recv.cpp 对照。网页快照及来源清单在证据目录。
- 复用旧索引作定位，当前版本函数表重新核实后取证双端 28 个 DT 绑定，并补客户端接收表、六类型/四字符串接收代理和 Lua 派发辅助函数。当前表布局双端均 name/signature/function/0，不能按旧版 server 布局选错槽。新版 redll 已支持 _new；本批显式选择已匹配 Steam 的工程，早期旧命令标签产生的来源注释已按实际工程 SHA256/MD5 更正。
- 实体自身保存 Bool/Float/Int/Vector/Angle/Entity 各32槽、String四槽，直接接入 BaseEntity SendTable/RecvTable、预测描述及存档描述。Int 按32位转换，Float按32位存储，字符串511字节上限，Entity用完整弱句柄。类型互相独立；索引按原生截断，越界 getter 回槽0、setter不写。NULL及参数错误不再被 DT 方法的旧 false 空桩吞掉，其他 NULL shim 未在本轮全局重写。
- 原版 DTVar_ReceiveProxyGL / InstallDataTable / editvariable 接收部分以未修改函数原文并入已有 original/entity_helpers.lua；variable_edit.lua 整文件恢复原版。SENT、SWEP 初始化改为实例绑定后 InstallDataTable -> SetupDataTables -> Initialize；原版 player_manager 自己的 InstallDataTable 调用保留。没有声称旧实体工厂和所有 OnEntityCreated 顺序都已重构。
- 原版 Lua 负责 NetworkVar/Notify/Element、自动槽位、self.dt、KeyName/Edit、复制和编辑数据。客户端接收代理只在值变化时于写入前派发原版通知，Lua命名setter仍保留原版相同值也通知的行为。
- 删除旧 Lua DT/NW 路由块和武器 NetworkVar/nwseed/nwrequest；停止发布旧私有 C++ 声明工厂。NW/NW2 的既有通路未删；共享文件中耦合的旧私有静态辅助代码尚未整体清理，但不再由本批声明链调用。
- 载具 Bool/Float/String slot3 也读取实际 DT 槽；旧 C++ 私有载具字段暂保留同步镜像，兼容既有输入路径。车辆/座椅类名输入同步写DT String3，避免旧64字节字段限制原生512字节槽。原版 Vehicle Lua 不改。
- 两个公共实体头改变布局，未新增或移动 virtual。按真实引用闭包和 client/server 任务变体精准清理对象，非整目录删除；最终1280个唯一对象全部回验新于两个头。清单包含 public/lua 对象以及同一共享源码的两端变体。首次清单1075项，后补205项，其中199项仍旧；没有在清理不完整时部署。compile_commands.json 不完整记录两端变体，不能只清其中列出的单个 .o。
- 修改 cpp 单 TU 通过，布局构建4m28.700s，补遗漏变体50.963s，最终增量21.961s。client/server DLL/PDB直接部署并四对SHA256通过。未启动游戏、未运行 native test、未提交推送、未生成 resulttxt。内容仓addons、运行数据和另一会话改动未动。
- 开始时读取到10:55的日志片段；收尾时原日志文件已不在原位置，已记录缺失，不将旧片段冒充最终游戏验证。具体日志缺失和部署哈希见 verification.json/deployment.json。
- 本批证据 D:/tmp/entity_dt_migration_20261027；双端新取证 D:/tmp/redll/client.dll、server.dll，索引与语义已回填。原生NPC射击连续性仍未在本轮处理。

快速验证：必须完整退出并重启，进图后先装备 GMod 相机武器。在停止缩放/旋转后分别执行，两个端的 Zoom/Roll 数值应一致：

```text
lua_run local w=player.GetAll()[1]:GetActiveWeapon() print(w:GetClass(),w:GetZoom(),w:GetRoll())
lua_run_cl local w=LocalPlayer():GetActiveWeapon() print(w:GetClass(),w:GetZoom(),w:GetRoll())
```

再检查拳头攻击、气球 Force 调整、可编辑实体/天空参数、载具 Ctrl 与滚轮。原来的 nwseed 请求日志应消失。不要仅凭入口存在或两项数字一致就认定所有插件/预测/PVS已实测完成。

可选的隔离底层探针，只在控制台手动执行；生成一只测试箱子，不覆盖玩家或已有武器的数据槽：

```text
lua_run local p=player.GetAll()[1] DTProbe=ents.Create("prop_physics") DTProbe:SetModel("models/props_junk/wood_crate001a.mdl") DTProbe:SetPos(p:GetShootPos()+p:GetAimVector()*80) DTProbe:Spawn() DTProbe:SetDTInt(31,12345) DTProbe:SetDTFloat(31,12.5) DTProbe:SetDTString(3,string.rep("a",600)) print(DTProbe:EntIndex(),DTProbe:GetDTFloat(31),#DTProbe:GetDTString(3))
lua_run_cl for _,e in ipairs(ents.FindByClass("prop_physics")) do if e:GetDTInt(31)==12345 then print(e:EntIndex(),e:GetDTFloat(31),#e:GetDTString(3)) end end
lua_run if IsValid(DTProbe) then DTProbe:Remove() end DTProbe=nil
```

服务器生成后稍等一秒再执行客户端查询，预期同一实体编号、12.5、511；最后一行删除探针。这些命令未由代理自动执行。


## 2026-10-27 DT receiver type regression

- User18:29-18:30 session logs show original entity_helpers SetZoom/GetZoom failing in native GetFunc: Entity expected, got userdata. No missing method was independently logged; the camera's setup/Equip failed because the preceding round rejected valid Weapon receivers.
- Root cause is the new HL2SB_DTEntity and SetDTEntity value check comparing metatable.__type to literal entity. luasrc_install_type_names intentionally stamps Entity/Player/Weapon/Vehicle/NPC/NextBot; the earlier lower-case values are overwritten during complete bootstrap. Source exists, yet a valid userdata was rejected before accessing its slots.
- Reused current-version client/server GetDTFloat and SetDTEntity typed-slot archives and verified actual Steam SHA256 unchanged. Both binaries test TYPE_ENTITY family, not a string display name. Reopened Facepunch Entity:NetworkVar and Entity:GetDTFloat pages; original installer intentionally captures an Entity/Weapon and calls its native getters. No new reverse needed, no repeated extraction.
- Fix only game/shared/lua/lbaseentity_shared.cpp: raw full-userdata and exact handle-size gate, then identity check against actual registered entity-family metatables using luaL_testudata. Covers base/animating/flex/combatcharacter/player/HL2MP/weapon/vehicle/NPC/NextBot. Receiver still errors for NULL; SetDTEntity accepts nil/NULL value while rejecting wrong typed userdata. No display-name string dependency, no blind reinterpret of arbitrary userdata.
- No original Lua, addon, public header or network table change. No object cleanup needed. Single TU and client/server build succeed (1m17.022s); direct DLL/PDB deployment hashes recorded at D:/tmp/dt_receiver_regression_20261027/deployment.json. No game launch, native test, resulttxt or commit/push. Live retest remains user task.
- Important lesson: entity type display names and native TYPE_ENTITY membership are different. Never validate an entity family by requiring __type == entity. Verify complete bootstrap as well as initial registrations.

Quick test after fully quitting/restarting: enter a map, equip GMod camera; startup should not show entity_helpers GetFunc Entity-expected errors. Execute each realm after stopping zoom/roll:

```text
lua_run local w=player.GetAll()[1]:GetActiveWeapon() print(w:GetClass(),w:GetZoom(),w:GetRoll())
lua_run_cl local w=LocalPlayer():GetActiveWeapon() print(w:GetClass(),w:GetZoom(),w:GetRoll())
```

Expected: gmod_camera and matching finite Zoom/Roll values, no Lua traceback. Check fists attacks and normal weapon switching as before. These commands are provided for manual validation, not automatically executed.


## 2026-10-27 Fists secondary punch callback shadow

- User corrects symptom to RIGHT mouse button failing to produce the right punch; predates DT migration. Latest18:45-18:46 log has no new Lua exception for fists. No automatic game launch.
- Exact original weapon_fists/shared.lua is byte-identical to actual Steam lua/weapons/weapon_fists.lua. Its SecondaryAttack calls self:PrimaryAttack(true), which chooses fists_right; primary without right chooses fists_left. Original Weapon.__index searches Weapon and Entity metatables before instance table.
- Fork exported CBaseCombatWeapon PrimaryAttack/SecondaryAttack directly into Weapon metatable. These take no Lua optional argument, call virtual methods and re-enter script with only self. Thus original SecondaryAttack's true is discarded through native PrimaryAttack, producing left punch. This is a script lookup defect, not evidence for reversing mouse or changing animations.
- Current actual Steam client/server named registration scans found no PrimaryAttack/SecondaryAttack export, while neighboring expected GetNextPrimaryFire anchors were found. Inventories and hashes archived as Weapon.AttackLuaExports.Fists20261027.txt in both redll module dirs, indexes updated. Wiki WEAPON:SecondaryAttack consulted as the right-click callback contract; original Lua establishes right-punch behavior. No repeated binary decompile was needed for absent exports.
- Removed only the two extra native Lua registration entries and unused wrapper functions in game/shared/lua/lbasecombatweapon_shared.cpp. Native C++ virtual methods and ItemPostFrame dispatch remain. Original fists and all other Lua untouched. This also avoids the same argument loss for other SWEPs calling custom PrimaryAttack arguments.
- No header changes or object cleanup. Single TU succeeds, client/server build22.318s; direct DLL/PDB four SHA256 pairs in D:/tmp/fists_secondary_20261027/deployment.json. No native test, game launch, resulttxt or commit/push. Actual punch visual and damage pending user retest.
- Quick manual validation after full restart: equip fists, aim at empty space (avoid combo uppercut), left click should give left fist; wait at least1 second, right click should give right fist. Then alternate on a target and verify damage plus third-hit combo. Toolgun left/right and camera right-click are useful short regressions. DT batch was user-tested without regression before this separate existing punch issue.


## 2026-10-27 Fists holdtype stale translation cache

- User live client outputs: GetHoldType=fist; TranslateActivity(ACT_MP_STAND_IDLE)=998 while ACT_HL2MP_IDLE_FIST=1138; SelectWeightedSequence(FIST)=381; active sequence idle_pistol. This proves state/translation mismatch and usable fist model sequence, not missing model animation. Server values not supplied.
- Reviewed native HoldType archive and original sh_anim.lua. Wiki Weapon:SetHoldType states it calls SetWeaponHoldType and networks state. Fresh weapons.Get instance contains base pistol ActivityTranslate until original mapper is applied. Fork applied-string cache survived Lua table replacement and marked calls applied even without a valid/successful handler; a pre-bind update can suppress mapping for the replacement table. This structural failure matches the observed mismatch but was not automatically reproduced in a live game.
- Fix weapon_hl2mpbase_scriptedweapon.cpp: invalidate applied string when installing a fresh Lua instance; call original mapping with saved stack and recursion guard; cache only a successful call and the actual requested string used by that call. lbasecombatweapon_shared.cpp setter applies pending mapping immediately after storing native holdtype. Native network string and existing enum layout remain; no new fallback animation table, no Lua edits.
- Two TUs compile, client/server final build30.402s; direct DLL/PDB four SHA256 pairs in D:/tmp/fists_holdtype_regression_20261027/deployment.json. No header changes or .o cleanup. No native test/game launch/resulttxt/commit/push. Actual third-person pose is pending user retest.
- After complete restart, equip fists and execute: lua_run_cl print(LocalPlayer():GetActiveWeapon():TranslateActivity(ACT_MP_STAND_IDLE),ACT_HL2MP_IDLE_FIST). Both should be1138 in current enum layout. Mirror should show fists stance; switch to toolgun/camera and back to verify mapping does not get stuck. Do not treat GetHoldType=fist alone as proof the mapping is current.


## 2026-10-27 Console EOF and selection copy parity

- User linked nillerusr/source-engine PR #454. The patch fixes RichText selection painting by splitting draw spans when entering/exiting selection boundaries; it does not replace the clipboard API. Applied the same four boundary conditions to vgui2/vgui_controls/RichText.cpp. Native Ctrl+C/Cut still use TextEntry/RichText CopySelected -> system()->SetClipboardText.
- Console EOF root: CConsolePanel stored partial text and completion/submit command in 256-byte buffers, while CCommand tokenizer accepts up to 512 bytes. Long lua_run/lua_run_cl input was truncated before Lua parsing, so an incomplete string/chunk ended with EOF or a missing ')' near end. Raised console-side buffers to 512, matching the parser capacity; no parser leniency or Lua EOF behavior changed.
- Exact GameUI current DLL was scanned for CommandSubmitted/submit/ConsoleEntry/DoCopySelected string callers and stored at D:/tmp/console_input_20261027/GameUI.dll with current Steam SHA256 and xrefs. redll import of GameUI had a Windows path quoting failure in the first attempt; source copy and xref evidence are retained, no product impact. PR source patch is the authoritative selection reference.
- Changed vgui2 RichText.cpp, vgui2 consoledialog.cpp and public ConsoleDialog.h. No public engine/game entity layout change. Single TU checks for GameConsoleDialog/consoledialog/RichText passed; vgui_controls+GameUI build12.489s. Deployed GameUI.dll/PDB to D:/srceng/bin with matching hashes. No game launch, native test, resulttxt, commit or push.
- Quick test after restart: open console and type a Lua command just below/above 256 characters with a quoted string; it should reach Lua intact rather than EOF. In console history, drag-select across a wrapped line boundary; selection highlight should stop at the exact selection endpoints, then Ctrl+C and paste into a text field. Also test Ctrl+X and Ctrl+V.


## 2026-10-27 Weapon base shared 原版替换与 native CallOnClient

- 用户要求后续工作全部双向核对。本批实际执行 Wiki、GMod 当前 Steam 双端二进制、原版 Lua、Valve SDK 源码四方核对；找不到页面时先请求用户提供地址，不把 404 当作功能缺失。之后每批按此规则。
- 已核对并保存 Wiki：Weapon:LastShootTime、Weapon:SetLastShootTime、Weapon:CallOnClient。Wiki 结论：LastShootTime 返回本地上次 FireBullets 时间；SetLastShootTime 默认当前时间、服务器写入不自动同步客户端；CallOnClient 仅服务器有效、owner-only usermessage、方法名和 data 合计不超过254字节。
- 当前 Steam 双端取证：LastShootTime/SetLastShootTime 都读写 CBaseCombatWeapon 的 native double 槽；脚本武器和普通武器共享它。FireBullets 入口在开火前写当前时间。没有增加网络同步。CallOnClient 服务端校验拥有者，发送可靠 SWEPCmd，编码完整 entity index+serial；客户端校验 serial 和 IsWeapon 后再找 Lua 方法。客户端调用为空操作。DefaultReload 仍走 native 当前 clip 与玩家 reload 动画。
- `weapon_base/shared.lua` 已整体替换为当前 GMod 原版；`init.lua`、`ai_translations.lua`、`sh_anim.lua` 也保持原版。`cl_init.lua` 只剩一处空格格式差异，内容和运行语义未自定义修改。旧 Lua LastShootTime、nwseed/nwrequest、CallOnClient 网络包装和 Entity 广播 RPC 均移除。普通 Entity:CallOnClient 不再作为武器通路保留。
- 旧 SWEPCmd 中间层也已改成原版消息名和 owner-only 语义，不广播给所有客户端。脚本接收器限制方法缓冲32、data缓冲256，与 usermessage 合计限制一致；服务器超长只记录并丢弃，不破坏 Lua 栈。
- 原版 shared Lua 中 `DefaultReload(ACT_VM_RELOAD)` 由 native binding 接受单参并填当前两个最大 clip，保留现有兼容签名；没有新增 Lua 侧装填动画。
- 头文件增加 realm-local double 成员，无 virtual；按真实包含闭包和 client/server 变体精准清理1280个对象，其中1274个旧对象，最终所有消费者时间戳新于头文件。未清 engine、lua_shared 或第三方对象。
- 单 TU 五个改动源全通过；最终 client/server 构建5m32.711s，直接部署 DLL/PDB 四对SHA256一致。未启动游戏、未运行 native test、未提交推送、未生成resulttxt。证据 `D:/tmp/weapon_base_final_20261027`，当前Steam双端新归档在 `D:/tmp/redll/client.dll` 和 `server.dll`，索引已回填。
- 日志先读到 20:56-20:57，唯一 Lua 报错为用户手动 `lua_run_cl` 调用缺失 `TranslateActivity`；这不是本批回归根因，已记录为后续 weapon binding 缺口。其余为已记录 shader/SkyPaint 警告。未把这些日志当作游戏验证通过。

快速验证：完整退出并重启后，依次测试拳头、工具枪、相机和插件武器。

```text
lua_run local w=player.GetAll()[1]:GetActiveWeapon() print(w:GetClass(),w:LastShootTime())
lua_run_cl local w=LocalPlayer():GetActiveWeapon() print(w:GetClass(),w:LastShootTime())
lua_run_cl print(type(LocalPlayer():GetActiveWeapon().CallOnClient))
```

开火前后本地 `LastShootTime()` 应随本地 FireBullets 改变；服务器设置后客户端不应自动跟随。检查武器拥有者是否只收到自己的 CallOnClient 方法调用。再测试换武器、装填、拳头攻击和工具枪动画。没有实际调用 `CallOnClient` 的插件时，不要仅凭方法存在判定消息链完全通过。

## 2026-10-29 Team and sandbox commands

- Restored the Steam GMod versions of `team.lua`, base `player.lua` and `cl_scoreboard.lua`, sandbox `shared.lua` and `commands.lua`. The five installed files match the reference MD5.
- The player team Lua setter dispatches the team-change hook before updating the player field. Entity and player-resource team fields use signed 16-bit network values; client `Player:Team()` reads the player resource. The default team globals are registered before Lua modules load.
- Updated spectator checks for the GMod spectator team and guarded HL2MP engine-team lookups. Replaced the Lua `NearestPoint` approximation with the shared native collision-property operation.
- Original `team.lua` passed an isolated Lua contract check for default teams, registration, player iteration, score and spawn-point lookup. Client and server DLL/PDB were built and deployed with matching MD5. The user confirmed client `Player:Team()` returns 7 after changing the server team and resuming singleplayer simulation. Multiplayer synchronization, spectator transitions and the remaining Sandbox spawn paths still require separate live validation.
- Removed duplicate player-resource creation and temporary resource diagnostics. The standard world lifecycle now creates one resource, and destroying a resource only clears the singleton it owns.
## 2026-10-29 Bokeh DOF migration

- Original motion_blur.lua is retained; user compared GMod and hl2box with pp_motionblur 1 and reported both working.
- Added byte-identical Steam GMod bokeh_dof.lua. Client NeedsDepthPass runs after main-view world list preparation and invokes the existing SSAO depth pass when requested; render.GetResolvedFullFrameDepth exposes the engine target. Server is not changed: this is a client postprocess and the current server reference has neither binding nor hook.
- Current Steam client depth hook, depth pass, and texture binding were reverse checked and archived under D:/tmp/redll/client.dll with index entries. The existing Source depth path is the implementation base; exact pixel parity, nested views and performance require live verification.
- Both changed client translation units passed single-TU compilation and client build succeeded. Client DLL/PDB were deployed and MD5 matched. No game launch or native tests. Remaining dof.lua, frame_blend.lua and super_dof.lua are not complete.

## 2026-10-29 DOF investigation

- User compared bokeh between GMod and hl2box and reported matching visual results.
- Current Steam reference DOFModeHack switches render groups and resets on level shutdown. The original dof_node effect calls IsValid, Remove, SetCollisionBounds, SetParent and transform methods.
- Current CLuaEffect is a table driven by a global client-effect draw list, with no real entity render handle or Remove implementation. GMod Entity:Remove rejects calls during rendering and defers client entity removal. Directly marking a table or remapping all render groups is not sufficient to establish equivalent effect placement, sorting and removal; further native lifecycle and render-order work remains before loading original dof.lua.
- Current Steam Entity Remove and SetCollisionBounds bindings and removal implementation archived in D:/tmp/redll/client.dll with index. No product changes or deployment for DOF in this investigation.


## 2026-10-29 DOF implementation

- Restored Steam GMod postprocess/dof.lua byte-for-byte. Existing dof_node remains unchanged.
- Added a client sorted renderable for dof_node, effect removal state, DOFModeHack group mapping and level-shutdown reset. Other Lua effects retain their existing draw path. This is a host adaptation, not proof of identical native lifecycle or all derived render-group behavior.
- Current GMod DOFModeHack, entity render-group and Remove behavior were archived under D:/tmp/redll/client.dll; see index. No header changes. Changed client translation units passed individual compilation and client build. Client DLL/PDB and original Lua were deployed and MD5 matched.
- User confirmed motion blur and bokeh after comparing them with GMod, and confirmed the DOF issue was fixed. The DOF first-frame error was addressed by updating sorted effects before rendering. Repeated toggling and map changes remain separate regression checks.

## 2026-10-29 Frame Blend migration

- Restored frame_blend.lua byte-for-byte from the current Steam installation. Added client GetRenderTargetEx, render.GetMoBlurTex1 and the three render target constants consumed by the script; engine.IsPlayingDemo and PostRender already exist.
- Current Steam client target bindings and creation helper are archived in D:/tmp/redll/client.dll and indexed. Current server binary contains none of these client APIs. The native image format range is limited to formats supported by this engine, so newer GMod formats remain unsupported.
- lrender.cpp passed single-TU compilation and client build succeeded. Client DLL/PDB deployed with matching MD5. User compared frame blend in game with GMod and reported matching behavior; demo recording remains untested.

## 2026-10-29 Super DOF migration

- Restored the current Steam super_dof.lua byte-for-byte. Updated both SuperFP textures to full-frame floating-point targets; added render.Spin, screenshot panel visibility, GUIMouseReleased dispatch and PreventScreenClicks handling.
- Current Steam client target helpers, screenshot binding and rope manager used by Spin are archived in D:/tmp/redll/client.dll and indexed. The corresponding target and Spin bindings do not appear in the current server binary. Client UI and input integration needs live verification, including context-menu regression checks.
- Changed translation units passed single-TU compilation; client and vgui_controls build succeeded. Client DLL/PDB deployed with matching MD5. Game testing, screenshot output, high quality rendering and cross-platform behavior remain unverified.

## 2026-10-30 Entity creation and scripted factory alignment

- Latest server and client logs were checked first. No new Lua traceback was present; remaining shader, material-variable and SteamHTMLSurface messages are unrelated warnings.
- Corrected the entity creation path to preserve GMod's unspawned `ents.Create` lifecycle. Scripted entities are bound when created, but `Initialize` and engine spawn now wait for the script's explicit `ent:Spawn()` call.
- Added a native fallback for classes present in `scripted_ents.GetStored` but registered at runtime without a file-backed factory. The normal engine factory is installed lazily and creation is retried; nextbot classes remain excluded from the generic animating fallback.
- GMod current client/server entity creation behavior was checked with the current Steam binaries and the official API contract. No original Lua was changed. `lbaseentity_shared.cpp` and `lentities.cpp` passed single-TU compilation; client/server build succeeded and DLL/PDB deployment hashes match.
- Live testing is still required: `ents.Create` followed by field/model setup then `Spawn`, runtime `scripted_ents.Register` classes, widget bone editing, constraints, and ordinary prop/NPC creation.
- Follow-up from the first live check: runtime factory creation succeeded, but the first probe emitted a pre-fallback unknown-class warning; the factory is now ensured before the initial create attempt. The same check exposed the real bone-widget failure: runtime widget tables were replacing file tables without inheriting missing base methods. `CBaseScripted::LoadScriptedEntity` now merges only missing fields from the file-backed entity table, preserving runtime overrides while restoring widget_base:SetSize and related methods. Client/server were rebuilt and redeployed; the bone editor still needs one fresh restart test.
- Second live check still reached the C++ `Entity:SetSize(Vector,Vector)` path. The missing piece was a second level of runtime inheritance: `widget_bone` is registered from `widget_bones.lua`, then derives from `widget_base`, whose `SetSize(number)` lives in the separately loaded file class. The loader now walks the runtime `Base` chain and merges each missing base field before binding the instance. The server was rebuilt after this final source change and both DLL/PDB pairs were redeployed. Restart and retest bone editing.
- Third live check showed the same dispatch can still occur for a partially registered widget instance. Added a narrow C++ fallback for the GMod widget contract: `Entity:SetSize(number)` now sets the BBox and stores the SizeVar value, while `GetSizeVar`/`SetSizeVar` have matching entity-side fallbacks. This keeps the original vector overload unchanged and prevents a failed widget setup from leaving the bone overlay in the world. Latest client/server artifacts were deployed with matching MD5 values.
- Fourth live check showed the remaining visual symptom precisely: `render.DrawBeam` was running, but its width was `0.00` and bone lengths were `1~2`, proving the generated NetworkVar accessor was still holding the default SizeVar. Numeric SetSize now forwards to the real per-instance `SetSizeVar` closure when present, then keeps the fallback value. Client/server were rebuilt and redeployed again; retest after a full restart.

## 2026-10-30 Super DOF input regression

- Restricted world mouse press/release dispatch to screen-click panels. Ordinary menu controls and sliders no longer trigger world focus selection or spawnmenu close. User confirmed both sliders and spawnmenu blank-area clicks work after the fix.
- Corrected the nested RenderView depth counter so the outer view also releases its entry on return.
- Follow-up: the client Lua world root had disabled its own hit testing, leaving scene space outside the Super DOF window without a mouse receiver. Enabled root hit testing while retaining normal child-first traversal, so the original focus selection and Sparks path can receive scene clicks. Awaiting user verification of this follow-up.

## 2026-10-30 Super DOF native effects

- Reviewed spark registrations against the current Steam callbacks. Corrected Sparks magnitude rounding to ceil and scale to truncation; ElectricSpark truncates both values. Super DOF uses fixed effect parameters independent of blur controls.
- Client util.Effect now dispatches directly to the Lua/native effect callbacks, matching the current reference path, instead of passing native effects through temporary-entity prediction filtering. The per-call allowOverride flag is honored without a second Lua override attempt. Existing native weapon prediction entry remains unchanged.
- Evidence is indexed under D:/tmp/redll/client.dll; Wiki effect and world mouse hook contracts checked. Original super_dof.lua remains byte-identical. Related translation units and client build passed; deployed DLL/PDB MD5 pairs match. Latest logs do not capture the failed Sparks invocation; actual scene picking and particle visibility require user retest.

## 2026-10-30 Super DOF world input traversal

- User confirmed standalone Sparks works. The 04:37 native snapshot identifies Engine Tools as the actual hovered panel during scene clicks; the Lua world root resolves correctly at the same coordinates. Empty Lua hover was caused by failure to wrap a panel from another module, not proof of a missing native target. Earlier ancestor-input diagnoses were not the observed root cause.
- Current Steam CGModBase constructor parents the world root to PANEL_ROOT and sets layer 90; Engine Tools is layer 75 and GameUI is layer 100. Box instead parented the Lua root under PANEL_CLIENTDLL at layer 25. Updated ClientModeShared::Enable to match the reference parent and layer; no original Lua changes.
- Removed the unsuccessful world-hit fallback, focus-validation exception, callback export, shutdown bridge and extra build dependency. InputWin32.cpp is restored to its prior implementation. Removed the temporary native snapshot command and Lua probe; captured evidence remains outside the repositories.
- New parent/layer helpers and engine root construction are archived and indexed under D:/tmp/redll/client.dll and engine.dll. Related single-TU checks and vgui2/client build passed; DLL/PDB pairs were deployed to their correct engine/game directories with matching MD5. User reports the issue appears fixed after testing; full screenshot output and menu regression checks remain separate validation items.

## 2026-10-30 Retire duplicate Angle global fallbacks

- Removed the duplicate Lua constructor/type aliases and the separate zero-vector/zero-angle fallbacks. The unmodified base `util.lua` supplies the canonical constants after native value types are registered.
- Reversed current Steam server and client Angle global registration and metatable behavior. Native constructor supports numeric, string, and Angle-copy inputs. The metatable now uses the GMod `Angle` type/name and provides the native mutators, conversion methods, normalization, randomization, and operators. GMod's original `angle.lua` remains byte-identical.
- The first live check found method lookup was being shadowed by component-name lookup (`Right` became roll, likewise `RotateAroundAxis`); it also found unsupported precision formatting through `lua_pushfstring`. Corrected lookup order and switched `__tostring` to the engine formatter. No Lua 5.1 compatibility patch or original Lua edits were made.
- Client/server single-TU checks and full builds passed. DLL/PDB artifacts were deployed to `bin` with matching MD5 values. User verified `Right` and `RotateAroundAxis` in both realms; type, constructor overload, and remaining methods still have separate short console checks.
