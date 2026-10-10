# hl2box 移植状态与 TODO 清单

hl2box（半条命 2 沙盒，迁移前内部名 hl2sb）对 GMod 的功能移植打钩清单。
图例：`[x]` 完成 / `[ ]` 待做 / `[~]` 部分完成 / `[-]` 刻意不做（含理由）。
库清单基准：GMod wiki 全部 88 个 Lua 库（经 libgmod 权威绑定表核对，2026-10-10）。

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

- [ ] `physenv`（GetGravity/SetGravity/GetAirDensity/SetAirDensity/GetPerformanceSettings）
- [ ] `serverlist`（服务器列表查询）
- [ ] `mesh`（IMesh 动态网格）
- [ ] `SendLua` 通道（现为收下不做事）
- [ ] `GM:CalcView` 载具派发（第一人称身体插件的载具眼睛吸附依赖）

## 二、Gamemode 与游戏系统

### 已完成

- [x] base gamemode（sandbox 经 table.inherit 继承）
- [x] 计分体系：`GM:DoPlayerDeath(ply, attacker, dmginfo)` 三参派发 + Lua 计分（引擎零计分，GMod 同位）
- [x] 记分板：GMod 原版骨架 + nosteam `AvatarImage`（data/avatars 文件方案）+ 麦克风图标 + `+showscoreboard`
- [x] player_manager 每关生成 + frags/ping 双端网络化
- [x] 拾取 HUD（服务端声明种类 + Lua 折叠 + 弹药袋合并）
- [x] undo 通知链（单消费者）
- [x] 创建服务器全屏 UI（gamemode 列表/地图缩略图/设置；gamemode 选择不被打回）
- [x] spawnmenu v4（Entities/Weapons/NPCs/Vehicles 四注册表、本地化、快照缩略图、触控模式）
- [x] 玩家模型菜单（扫描 + 插件注册 + 文字列表 + SpawnIcon 快照）
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

### 部分

- [~] halo：`IMaterial:SetString` 数值向量解析、DrawScreenQuad 内建 2D 推送两项引擎修复未落地
- [~] 物理枪对齐：见 P1（已逐项反编译定案，纯机械）
- [~] 语音：引擎录制停止修复已部署；语音面板（cl_voice）未移植
- [~] NextBot：base_nextbot + C++ 侧在；API 差异未清点
- [~] 聊天链：服务端 PlayerSay 在；OnPlayerChat/chat.AddText 客户端半环缺
- [~] duplicator：模块在，工具枪存档端到端未验
- [~] 字体/选队/成就显示：随场景补

## 三、TODO（按优先级）

### P1

- [ ] 物理枪对齐清单（已逐项反编译定案，纯机械活）：
  - [ ] ConVar：`physgun_teleportDistance`→0、`physgun_maxAngular`→5000、`gm_snapangles`→0；新增 `physgun_DampingFactor`(0.8)、`gm_snapgrid`(0)；加 REPLICATED 与范围边界
  - [ ] 质量：抓取抬升到 45678 + 哨兵 -1 + 车辆类名判定
  - [ ] 冻结走 SecondaryAttack + 0.5s 双攻击冷却门
  - [ ] 动画二态：持物 RECOIL1 / 空闲 IDLE
  - [ ] 删扫描循环声（参考双端零音效）
  - [ ] R 键 10ms 闸；hold 门掩码精确化
- [ ] halo：`IMaterial:SetString` 数值向量解析（"$color [1 1 1]" 黑屏根因）
- [ ] halo：`render.DrawScreenQuad` 内建 2D 视口推送
- [ ] 物理枪+halo 重做轮收尾（此前一轮重写丢失，E3/E4 现状需先核对）
- [ ] 语音面板移植：说话开始/结束事件 → `PlayerStartVoice`/`PlayerEndVoice` 钩子；`Player:IsPlayerSpeaking` 绑定

### P2

- [ ] 聊天链客户端半环：`OnPlayerChat` / `chat.AddText`
- [ ] `SendLua` 通道（client-only Lua 队列）
- [ ] `variable_edit.lua`（引擎侧派发缺）
- [ ] `SetVoiceVolumeScale`（滚轮绑定）
- [ ] `physenv` 库（Get/SetGravity、AirDensity、PerformanceSettings）
- [ ] NPC 客户端 `m_iMaxHealth` 网络化（玩家侧已修；判满血/可治疗的 GMod SWEP 全部误判）
- [ ] duplicator + 工具枪端到端验证（存档/复制粘贴全链）
- [ ] vphysics ragdoll 加固：ledge 遍历守卫、坏对象定位探针、workshop .phy 加载期校验

### P3

- [ ] `cl_deathnotice` 与 C++ 击杀播报的共存策略
- [ ] `player_pickup`（+use 携带）子系统
- [ ] 运行时探针：`gm_snapangles 0` 时 E+SHIFT 写 NaN 的实测（静态已证实的原版 bug）；2x 抓距 vs 束半距意图确认
- [ ] NextBot API 差异全量清点
- [ ] `serverlist` / `frame_blend` / `video` 库（待需求）
- [ ] 游戏内热挂载（挂载游戏内容清单化）
- [ ] gmod 地图天空盒白观感深挖（无效顶点格式 mesh）
- [ ] SWEP 钩子补面：`TranslateFOV` / `HUDShouldDraw` / `AdjustMouseSensitivity` / `DrawWeaponSelection`

## 四、刻意不做（勿再提）

- [-] DHTML/CEF 全族（无浏览器层）
- [-] Steam 头像/steamworks（nosteam 文件方案：`data/avatars/<steamid64|name>.png`）
- [-] `IsMounted`/`engine.GetGames` 真实现（守卫恒 false 是 GMod 式注册文件依赖的语义）
- [-] `util.GetModelMeshes`、Decal 系、`PixelVisible`、undo 二进制导出（GMod 本来就没有）
- [-] gamemode 计分放引擎侧（GMod 放 Lua 的就放 Lua，移植期双计债）
- [-] `SWEP:ShouldDropOnDie`/`CustomAmmoDisplay`/`EquipAmmo`（无引擎路径）
