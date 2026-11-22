# KeyboardRescue · 键盘急救

当笔记本键盘上某个键**坏了**（卡住、连发、失灵），用软件方式撑到你有空换键盘为止。

- 单文件脚本，Windows 自带 PowerShell 就能跑，**无任何依赖**
- 所有修改都会**先备份**，一条命令即可还原
- 默认只做检测，真正动手需要显式加 `-Apply`

## 快速开始

```powershell
# 1. 找出是哪个键在"自己按下"
.\keyboard-rescue.ps1 detect

# 2. 吞掉这个键的连发（后台运行，Ctrl+C 停止）
.\keyboard-rescue.ps1 guard -Key I

# 3. 让守护开机自启（需管理员）
.\keyboard-rescue.ps1 guard -Key I -Install

# 4. 把坏键搬到备用键上（需管理员，重启生效）
.\keyboard-rescue.ps1 remap -Key I -To RCTRL -Apply

# 5. 或者干脆禁用坏键（需管理员，重启生效）
.\keyboard-rescue.ps1 disable -Key I -Apply

# 6. 一键还原
.\keyboard-rescue.ps1 restore -Apply
```

## 四个功能分别解决什么

| 命令 | 解决 | 原理 |
|---|---|---|
| `detect` | 不知道哪个键坏了 | 轮询 `GetAsyncKeyState`，抓"按住超过 1 秒"的键 |
| `guard` | 卡键导致刷屏 | 低级键盘钩子，吞掉同一键 120ms 内的重复按下 |
| `remap` | 坏键彻底不能用了 | 改扫描码映射，把坏键的功能搬到另一个键 |
| `disable` | 坏键一直误触发 | 改扫描码映射，把坏键映射为空 |
| `restore` | 想恢复原样 | 从备份还原扫描码映射 |

## 常见场景

**场景 A：某个键粘住了，一直自己打字**

```powershell
.\keyboard-rescue.ps1 detect          # 确认是哪个键
.\keyboard-rescue.ps1 guard -Key I -Install   # 装上守护，一劳永逸
```

**场景 B：某个键彻底按不出来了**

```powershell
.\keyboard-rescue.ps1 remap -Key I -To RCTRL -Apply
# 重启后，按右 Ctrl 就等于按 I
```

**场景 C：某个键疯狂误触发，影响使用**

```powershell
.\keyboard-rescue.ps1 disable -Key I -Apply
```

## 支持的按键名

字母 `A`–`Z`、数字 `0`–`9`，以及：

```
SPACE ENTER TAB BACKSPACE ESC CAPSLOCK
LCTRL RCTRL LALT RALT LSHIFT RSHIFT LWIN RWIN APPS
UP DOWN LEFT RIGHT HOME END PGUP PGDN INSERT DELETE
MINUS EQUAL LBRACKET RBRACKET SEMICOLON QUOTE BACKQUOTE BACKSLASH
COMMA PERIOD SLASH
```

## 注意事项

- `remap` / `disable` / `restore` **需要管理员权限**，并且**重启后生效**
- 修改前会在 `%LOCALAPPDATA%\KeyboardRescue\` 自动备份原映射
- `guard` 只在登录后运行（键盘钩子必须在你自己的桌面会话里）
- 这是**临时替代方案**，不是维修。键位硬件损坏的最终解法仍然是更换键盘
- 在需要长按的游戏中，`guard` 会影响对应按键

## 原理简述

笔记本键盘损坏常表现为 **"只发按下、不发松开"**，系统会认为键一直按着，从而不断自动连发。
Windows 的自动连发间隔约 30ms，而人手正常按键间隔一般 > 120ms。
`guard` 就是利用这个差值：同一按键 120ms 内的第二次按下直接丢弃。

## 配套文章

- [`article.md`](article.md)：一次真实的「AI 修键盘」记录，可直接用于公众号 / 博客。

## AI Skill

仓库内置了一个 OpenCode skill：`.opencode/skills/keyboard-rescue/`。

在该仓库目录下打开 OpenCode，直接描述症状（例如「我键盘某个键一直自己打字」），
AI 会自动加载 `keyboard-rescue` 技能，按「取证 → 判断 → 可回滚修复」的流程处理。

```
.opencode/skills/keyboard-rescue/
├── SKILL.md                    # 触发条件、排查流程、安全规则
├── references/keys.md          # 键位名与扫描码对照表
└── scripts/keyboard-rescue.ps1 # 脚本副本
```

## License

MIT
