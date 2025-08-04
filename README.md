# My Awesome macOS Customization

## Deskflow
[deskflow/deskflow](https://github.com/deskflow/deskflow)<br>
我用 Windows 笔记本控制 Mac Mini。

## Hammerspoon
[Hammerspoon/hammerspoon](https://github.com/Hammerspoon/hammerspoon) <br>
- `init.lua`

## 快捷指令
**使用方法**：制作快捷指令 - 右键快捷指令 - 添加到程序坞 - 右键程序坞里的应用 - 在访达中显示 - 按住 Cmd 拖到访达顶上 - 从程序坞中移除

- 新建文本文稿
```AppleScript
tell application "Finder"
	set dirPath to POSIX path of (target of front window as alias)
end tell
do shell script "touch " & quoted form of (dirPath & "未命名文本文稿.txt")
tell application "Finder"
	select ((POSIX file (dirPath & "未命名文本文稿.txt")) as alias)
	set viewMode to current view of front window as text
end tell
if viewMode is "list view" or viewMode is "column view" then
	delay 0.3 --- 被文件出现动画硬控 0.3 秒
end if
tell application "System Events"
	keystroke return
end tell
```

- 打开终端
```AppleScript
tell application "Finder"
	set dirPath to POSIX path of (target of front window as alias)
end tell
do shell script "open -a Terminal " & quoted form of dirPath
```

- 解锁应用程序
```AppleScript
tell application "Finder"
	set sel to selection
	if sel is {} then
		display dialog "请选择一个应用程序来解锁。" buttons {"知道了"} default button 1
		return
	end if

	set theItem to item 1 of sel
	set appPath to POSIX path of (theItem as alias)
	try
		do shell script "xattr -rd com.apple.quarantine " & quoted form of appPath
		display dialog "xattr -rd com.apple.quarantine " & (name of theItem) & "

如上，已移除不受信任来源标记。" buttons {"谢谢"} default button 1
	on error errMsg
		display dialog "xattr -rd com.apple.quarantine " & (name of theItem) & "

发生错误：" & errMsg buttons {"坏耶"} default button 1
	end try
end tell
```