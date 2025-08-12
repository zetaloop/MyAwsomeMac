hs = hs       -- type ignore

Watchers = {} -- 全局表来存储事件监听器
local types = hs.eventtap.event.types

-- 单击 Win(Ctrl) 键打开隐藏的程序坞
local WinPressed = false
local SingleWinFlag = false
Watchers.cmdTap = hs.eventtap.new(
    { types.flagsChanged, types.keyDown, types.leftMouseDown, types.rightMouseDown, types.otherMouseDown }, function(e)
        local t = e:getType()
        local flags = e:getFlags()
        if t == types.flagsChanged then
            -- 仅在首次检测到纯 ctrl 按下时启动
            if flags:containExactly({ "ctrl" }) and not WinPressed then
                WinPressed = true
                SingleWinFlag = true
                -- 在 ctrl 松开且之前未被取消时触发
            elseif flags:containExactly({}) and WinPressed then
                if SingleWinFlag then
                    -- hs.eventtap.keyStroke({ "ctrl", "fn" }, "F3")
                    -- 改为启动 启动台
                    hs.application.launchOrFocus("Launchpad")
                end
                WinPressed = false
                -- 其它任何修饰键变化（如按下或松开其他修饰键）都取消资格
            elseif WinPressed then
                SingleWinFlag = false
            end
            -- 在 ctrl 按住期间遇到任何普通键按下或鼠标点击，也取消资格
        elseif WinPressed and (t == types.keyDown or
                t == types.leftMouseDown or t == types.rightMouseDown or t == types.otherMouseDown) then
            SingleWinFlag = false
        end
        return false -- 不拦截事件，保持系统默认行为
    end):start()

-- Home/End 映射为 Ctrl+A/E
local homeKey, endKey = hs.keycodes.map["home"], hs.keycodes.map["end"]
local suppressCtrlAE, timerAE = false, nil
Watchers.homeEndTap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(e)
    local code, isDown = e:getKeyCode(), (e:getType() == types.keyDown)
    if code ~= homeKey and code ~= endKey then return false end

    suppressCtrlAE = true
    if timerAE then timerAE:stop() end
    timerAE = hs.timer.doAfter(0.1, function() suppressCtrlAE = false end)

    hs.eventtap.event.newKeyEvent({ "ctrl" }, code == homeKey and "a" or "e", isDown):post()
    return true
end):start()

-- Ctrl+Shift+V 纯文本粘贴
local keyV = hs.keycodes.map["v"]
Watchers.ctrlShiftVTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyV or not e:getFlags():containExactly({ "cmd", "shift" }) then
        return false
    end
    -- 获取纯文本；若无，则尝试从富文本提取
    local plain = hs.pasteboard.readString()
    if not plain then
        local styled = hs.pasteboard.readStyledText()
        if styled then plain = styled:getString() end
    end
    if not plain then plain = "" end

    hs.pasteboard.setContents(plain)
    hs.eventtap.keyStroke({ "cmd" }, "v")
    SingleWinFlag = false
    return true
end):start()

-- 终端里未选文本时 Ctrl+C 变为终止而不是复制
local isCopy = true
local keyC = hs.keycodes.map["c"]
Watchers.cmdCopyTap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(e)
    if e:getKeyCode() ~= keyC or not e:getFlags():containExactly({ "cmd" }) then
        return false
    end
    local app = hs.application.frontmostApplication()
    if not (app and app:bundleID() == "com.apple.Terminal") then
        return false
    end

    if e:getType() == types.keyDown then
        isCopy = true
        local copyItem = app:findMenuItem({ "编辑", "拷贝" })
        if copyItem and copyItem.enabled then
            hs.alert.show("Ctrl+C 复制", 0.3)
            return false
        end
        hs.alert.show("Ctrl+C 终止", 0.3)
        hs.eventtap.event.newKeyEvent({ "ctrl" }, "c", true):post()
        isCopy = false
        SingleWinFlag = false
        return true
    elseif e:getType() == types.keyUp then
        if isCopy then
            return false
        end
        hs.eventtap.event.newKeyEvent({ "ctrl" }, "c", false):post()
        isCopy = false
        SingleWinFlag = false
        return true
    end
end):start()


-- Ctrl+Space ⇄ Cmd+Space
local keySpace = hs.keycodes.map["space"]
local swapSpaceTap
swapSpaceTap = hs.eventtap.new({ types.keyDown, types.keyUp }, function(e)
    if e:getKeyCode() ~= keySpace then return false end

    local isDown = (e:getType() == types.keyDown)
    local flags  = e:getFlags()

    if flags:containExactly({ "ctrl" }) then -- ⌃ Space → ⌘ Space
        SingleWinFlag = false
        swapSpaceTap:stop()
        hs.eventtap.event.newKeyEvent({ "cmd" }, "space", isDown):post()
        swapSpaceTap:start()
        return true
    elseif flags:containExactly({ "cmd" }) then -- ⌘ Space → ⌃ Space
        SingleWinFlag = false
        swapSpaceTap:stop()
        hs.eventtap.event.newKeyEvent({ "ctrl" }, "space", isDown):post()
        swapSpaceTap:start()
        return true
    end
    return false
end):start()

-- 访达中剪切的提示
Watchers.finderCutTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= hs.keycodes.map["x"] or not e:getFlags():containExactly({ "cmd" }) then
        return false
    end
    -- 是访达
    local front = hs.application.frontmostApplication()
    if not (front and front:bundleID() == "com.apple.finder") then
        return false
    end
    -- 不是输入框
    local f = hs.uielement.focusedElement()
    if f and (f.role and f:role() == "AXTextField" or f.subrole and f:subrole() == "AXInlineTextField") then
        return false
    end
    hs.alert.show("您似乎在用 Ctrl+X 剪切文件？\n\nCtrl+C\t\t\t\t复制（帮你按了）\nCtrl+Alt+V\t\t粘贴并删除")
    hs.eventtap.keyStroke({ "cmd" }, "c")
    SingleWinFlag = false
    return false
end):start()

-- 访达中 delete 删除文件
Watchers.deleteTap = hs.eventtap.new({ types.keyDown }, function(e)
    -- 注意在 mac 中，backspace← 叫 delete，delete 叫 forwarddelete
    if e:getKeyCode() ~= hs.keycodes.map["forwarddelete"] then
        return false
    end
    -- 是访达
    local front = hs.application.frontmostApplication()
    if not (front and front:bundleID() == "com.apple.finder") then
        return false
    end
    -- 不是输入框
    local f = hs.uielement.focusedElement()
    if f and (f.role and f:role() == "AXTextField" or f.subrole and f:subrole() == "AXInlineTextField")
    then
        return false
    end
    -- 模拟一次 ⌘+backspace
    hs.eventtap.keyStroke({ "cmd" }, "delete")
    SingleWinFlag = false
    return true -- 不然可能会变成跳转到最后
end):start()

-- Ctrl+Shift+Esc 打开活动监视器 (任务管理器)
local keyEscape = hs.keycodes.map["escape"]
Watchers.taskManagerTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyEscape or not e:getFlags():containExactly({ "cmd", "shift" }) then
        return false
    end
    hs.application.launchOrFocus("Activity Monitor")
    SingleWinFlag = false
    return false
end):start()

-- Win+R 打开终端
local keyR = hs.keycodes.map["r"]
Watchers.ctrlRTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyR or not e:getFlags():containExactly({ "ctrl" }) then
        return false
    end

    local focusedApp = hs.application.frontmostApplication()
    -- 终端内忽略
    if focusedApp and focusedApp:bundleID() == "com.apple.Terminal" then
        hs.alert.show("Ctrl+R", 0.3)
        return false
    end
    -- 如果当前是访达，则在新终端中打开其路径
    if focusedApp and focusedApp:bundleID() == "com.apple.finder" then
        hs.osascript.applescript([[
            tell application "Finder"
                set dirPath to POSIX path of (target of front window as alias)
            end tell
            do shell script "open -a Terminal " & quoted form of dirPath
        ]])
    else
        -- 否则，仅打开新终端
        hs.osascript.applescript([[
            tell application "Terminal"
                activate
                do script ""
            end tell
        ]])
    end

    SingleWinFlag = false
    return true -- 拦截事件
end):start()

-- Win+E 打开访达
local keyE = hs.keycodes.map["e"]
Watchers.ctrlETap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyE or not e:getFlags():containExactly({ "ctrl" }) then
        return false
    end
    if suppressCtrlAE then return false end -- 防止与 Home/End -> Ctrl+A/E 冲突
    local focusedApp = hs.application.frontmostApplication()
    -- 终端内忽略
    if focusedApp and focusedApp:bundleID() == "com.apple.Terminal" then
        hs.alert.show("Ctrl+E", 0.3)
        return false
    end
    hs.osascript.applescript([[
        tell application "Finder"
            activate
            make new Finder window
        end tell
    ]])
    SingleWinFlag = false
    return false
end):start()

-- Win+I 打开设置
local keyI = hs.keycodes.map["i"]
Watchers.ctrlITap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyI or not e:getFlags():containExactly({ "ctrl" }) then
        return false
    end
    local focusedApp = hs.application.frontmostApplication()
    -- 终端内忽略
    if focusedApp and focusedApp:bundleID() == "com.apple.Terminal" then
        hs.alert.show("Ctrl+I", 0.3)
        return false
    end
    if not (hs.application.launchOrFocus("System Settings")
            or hs.application.launchOrFocus("System Preferences")) then
        hs.alert.show("无法打开设置")
    end
    SingleWinFlag = false
    return true
end):start()

-- Win+X 打开ChatGPT
local keyX = hs.keycodes.map["x"]
Watchers.ctrlXTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyX or not e:getFlags():containExactly({ "ctrl" }) then
        return false
    end
    local focusedApp = hs.application.frontmostApplication()
    -- 终端内忽略
    if focusedApp and focusedApp:bundleID() == "com.apple.Terminal" then
        hs.alert.show("Ctrl+X", 0.3)
        return false
    end
    if focusedApp and focusedApp:name() == "ChatGPT" then
        hs.eventtap.keyStroke({ "cmd" }, "q")
    else
        if not (hs.application.launchOrFocus("ChatGPT")
                or hs.application.launchOrFocus("ChatGPT")) then
            hs.alert.show("无法打开ChatGPT")
        end
    end
    SingleWinFlag = false
    return true
end):start()

-- Win+D 重启 Deskflow 和 Hammerspoon
local keyD = hs.keycodes.map["d"]
Watchers.ctrlDTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyD or not e:getFlags():containExactly({ "ctrl" }) then
        return false
    end
    local focusedApp = hs.application.frontmostApplication()
    -- 终端内忽略
    if focusedApp and focusedApp:bundleID() == "com.apple.Terminal" then
        hs.alert.show("Ctrl+D", 0.3)
        return false
    end
    hs.alert.show("Reload Deskflow & Hammerspoon")
    hs.timer.doAfter(0.1, function()
        hs.osascript.applescript([[
            tell application "System Events" to tell process "Deskflow" to click button "Restart" of window 1
        ]])
        hs.timer.doAfter(0.1, hs.reload)
    end)
    SingleWinFlag = false
    return true
end):start()

-- Win+B 显示当前活跃应用的 bundleID
local keyB = hs.keycodes.map["b"]
Watchers.ctrlBTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() ~= keyB or not e:getFlags():containExactly({ "ctrl" }) then
        return false
    end
    -- 获取并展示前台应用 bundleID
    local focusedApp = hs.application.frontmostApplication()
    local id         = focusedApp and focusedApp:bundleID() or "未知 bundleID"
    -- 终端内忽略
    if focusedApp and focusedApp:bundleID() == "com.apple.Terminal" then
        hs.alert.show("Ctrl+B", 0.3)
        return false
    end
    hs.alert.show(id, 1)
    SingleWinFlag = false
    return true
end):start()

-- Ctrl + 中键 取词（Textify）
local ax, mouse = require("hs.axuielement"), require("hs.mouse")

local function _getTextUnderMouse()
    local pt  = mouse.getAbsolutePosition()
    local sys = ax.systemWideElement()
    local el  = sys and sys:elementAtPosition(pt.x, pt.y)
    if not el then return nil end

    local function get(attr)
        local ok, v = pcall(function() return el:attributeValue(attr) end)
        return ok and type(v) == "string" and #v > 0 and v or nil
    end

    -- 优先级：选中文本 > 值 > 标题 > 描述/帮助/占位 > 值描述
    local order = { "AXSelectedText", "AXValue", "AXTitle", "AXDescription", "AXHelp", "AXPlaceholderValue",
        "AXValueDescription" }
    for _, a in ipairs(order) do
        local v = get(a)
        if v then return (v:gsub("%s+$", ""):gsub("^%s+", "")) end
    end
    if (get("AXRole") == "AXStaticText") then
        local v = get("AXValue")
        if v then return (v:gsub("%s+$", ""):gsub("^%s+", "")) end
    end
    return nil
end
Watchers.pickTextTap = hs.eventtap.new({ types.otherMouseDown }, function(e)
    local flags = e:getFlags()
    if not (flags:containExactly({ "cmd" })) then
        return false
    end
    local btn = e:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber)
    if btn ~= 2 then return false end

    local text = _getTextUnderMouse()
    SingleWinFlag = false
    if text and #text > 0 then
        hs.pasteboard.setContents(text)
        hs.alert.show(text)
    else
        hs.alert.show("未发现可读文本属性")
    end
    SingleWinFlag = false
    return true
end):start()

-- Shift+Space 修复中文输入法消失问题
Watchers.shiftSpaceTap = hs.eventtap.new({ types.keyDown }, function(e)
    if e:getKeyCode() == hs.keycodes.map["space"] and e:getFlags():containExactly({ "shift" }) then
        -- 空的提示框
        local chooser = hs.chooser.new(function(x) end)
        chooser:placeholderText("")
        chooser:show()
        -- 在输入框中输入
        hs.timer.doAfter(0, function() hs.eventtap.keyStrokes("好") end)
        hs.timer.doAfter(0.01, function() hs.eventtap.keyStroke({}, "l") end)
        hs.timer.doAfter(0.02, function() hs.eventtap.keyStroke({}, "space") end)
        hs.timer.doAfter(0.5, function() hs.eventtap.keyStroke({}, "escape") end)
    end
    SingleWinFlag = false
    return false
end):start()

-- 松开所有修饰键避免卡住
hs.timer.doAfter(0, function()
    -- 用 flagsChanged 清空全部修饰键
    hs.eventtap.event.newFlagsChangedEvent({}):post()
    -- 逐个发送 keyUp 以彻底确保释放
    for _, kc in ipairs({ 55, 54, 59, 62, 58, 61, 56, 60, 63 }) do
        hs.eventtap.event.newKeyEvent({}, kc, false):post()
    end
end)

hs.alert.show("Loaded uwu", 0.3)
