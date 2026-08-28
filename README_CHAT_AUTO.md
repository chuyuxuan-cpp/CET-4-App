# 讯飞智能体自动发送脚本

功能：开机后每 10 分钟自动打开 [讯飞智能体聊天页面](https://agent.xfyun.cn/agentbuilder/chat?botId=5647841)，发送“什么是SPFA算法”，等待 3 分钟后关闭浏览器。

 ## 发送方式
 
 脚本输入消息后会直接按 **回车键** 发送。该网站支持回车发送，这是最稳定、不会被弹窗遮挡的方式。

 ## 关于登录

 讯飞智能体页面需要先登录才能发送消息。脚本已做以下处理：
 
 1. 使用独立的浏览器配置文件目录 `E:\CET-4 App\browser_profile`，登录状态会保留。
 2. 如果弹出登录窗口，脚本会暂停并提示：
    ```
    检测到登录弹窗，请在 120 秒内完成登录...
    ```
    你在这 120 秒内手动扫码/输入账号登录即可，登录成功后脚本会自动继续。
 3. 第一次登录成功后，只要 `browser_profile` 目录不被删除，之后每次运行都会自动保持登录状态，无需再手动操作。
 
 如果登录后下次运行又弹出登录框，可能是网站会话过期，可以删除 `browser_profile` 目录重新登录一次。

 ## 依赖 ChromeDriver

 脚本需要 ChromeDriver 才能控制 Chrome。由于网络原因，自动下载可能失败，建议手动下载：

 1. 查看你的 Chrome 版本：打开 Chrome -> 设置 -> 关于 Chrome，例如 `128.0.xxxx.xx`。
 2. 到镜像站下载对应版本的 ChromeDriver：
    - 阿里云镜像：https://registry.npmmirror.com/binary.html?path=chromedriver/
    - 腾讯云镜像：https://mirrors.cloud.tencent.com/chromedriver/
    - 官方地址（需翻墙）：https://googlechromelabs.github.io/chrome-for-testing/
 3. 把下载的 `chromedriver.exe` 放到 `E:\CET-4 App\` 目录下（和 `chat_automation.py` 同级）。

 或者通过环境变量指定路径：

 ```powershell
 $env:CHROMEDRIVER_PATH="C:\Tools\chromedriver.exe"
 python chat_automation.py
 ```
 
 ## 使用 Edge 浏览器（推荐）
 
 脚本默认已经启用 Edge（`USE_EDGE = True`）。Windows 自带 Edge，只需要下载对应的 `msedgedriver.exe`：
 
 1. 查看 Edge 版本：打开 Edge -> 设置 -> 关于 Microsoft Edge，例如 `128.0.xxxx.xx`。
 2. 到镜像站下载对应版本的 Edge WebDriver：
    - 阿里云镜像：https://registry.npmmirror.com/binary.html?path=edgedriver/
    - 官方地址：https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver/
 3. 把下载的 `msedgedriver.exe` 放到 `E:\CET-4 App\` 目录下。
 
 或者通过环境变量指定：
 
 ```powershell
 $env:EDGEDRIVER_PATH="C:\Tools\msedgedriver.exe"
 python chat_automation.py
 ```
 
 如果想改回 Chrome，把 `chat_automation.py` 里的 `USE_EDGE = True` 改成 `USE_EDGE = False`。

 ## 1. 安装依赖

 需要 Python 3.8+ 和 Chrome 或 Edge 浏览器。

```powershell
pip install -r requirements.txt
```

## 2. 运行测试

手动运行一次，确认能正常发送消息：

```powershell
python chat_automation.py
```

如果页面加载后没有发送成功，请打开 Chrome 按 `F12` 检查聊天输入框和发送按钮的 HTML，把对应的选择器添加到 `chat_automation.py` 里的 `INPUT_SELECTORS` 和 `SEND_BUTTON_SELECTORS` 列表中。

## 3. 设置开机自动运行

### 方法 A：使用计划任务（推荐）

1. 右键点击 PowerShell，选择“以管理员身份运行”。
2. 执行：

```powershell
& "E:\CET-4 App\setup_startup.ps1"
```

3. 之后每次登录系统，任务都会每 10 分钟执行一次。
4. 如需停止或删除任务，打开“任务计划程序”，找到 `XfyunChatAutoSend` 删除即可。

### 方法 B：放入启动文件夹

1. 按 `Win + R`，输入 `shell:startup` 回车。
2. 将 `run_chat.bat` 的快捷方式拖入该文件夹。

注意：这种方式只会“开机启动脚本”，脚本的 10 分钟循环逻辑已经写在里面。

## 4. 配置说明

编辑 `chat_automation.py` 顶部的变量：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `MESSAGE` | 要发送的消息 | `什么是SPFA算法` |
 | `INTERVAL_MINUTES` | 两次执行间隔 | `10` |
 | `WAIT_AFTER_SEND_MINUTES` | 发送后保持打开的时长 | `3` |
 | `BROWSER_VISIBLE` | 是否显示浏览器窗口 | `True` |
 | `USE_EDGE` | 是否使用 Edge（False 则用 Chrome） | `True` |

## 5. 停止脚本

- 手动运行时直接按 `Ctrl + C`。
- 计划任务方式请到“任务计划程序”中禁用或删除 `XfyunChatAutoSend`。
