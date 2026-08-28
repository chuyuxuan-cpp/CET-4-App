#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
每 2 分钟自动打开讯飞智能体聊天页面，发送指定消息，40 秒后关闭浏览器。

用法：
    python chat_automation.py

环境要求：
    pip install -r requirements.txt
    需要安装 Chrome 或 Edge 浏览器
"""

import os
import time
import sys
from datetime import datetime

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service as ChromeService
from selenium.webdriver.edge.service import Service as EdgeService
from selenium.webdriver.edge.options import Options as EdgeOptions
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from webdriver_manager.microsoft import EdgeChromiumDriverManager

# ============ 可配置项 ============
# 如果已经手动下载了驱动，把它放在脚本同目录，或填写完整路径
# 也可以通过环境变量 CHROMEDRIVER_PATH / EDGEDRIVER_PATH 指定
CHROMEDRIVER_PATH = os.environ.get(
    "CHROMEDRIVER_PATH",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "chromedriver.exe")
)
EDGEDRIVER_PATH = os.environ.get(
    "EDGEDRIVER_PATH",
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "msedgedriver.exe")
)

CHAT_URL = "https://agent.xfyun.cn/agentbuilder/chat?botId=5647841"
MESSAGE = "什么是SPFA算法"
INTERVAL_SECONDS = 60      # 每次循环间隔（2分钟）
WAIT_AFTER_SEND_SECONDS = 35 # 发送后保持打开的时长（40秒）
BROWSER_VISIBLE = True      # True=显示浏览器，False=后台运行（部分网站对无头模式有限制）
USE_EDGE = True             # True=使用 Edge，False=使用 Chrome
LOGIN_TIMEOUT_SECONDS = 120 # 如果弹出登录窗口，等待用户登录的最长时间

# 常见聊天输入框定位方式，按优先级依次尝试
# 如果页面加载后无法发送消息，请按 F12 检查元素，把对应的选择器加进来
INPUT_SELECTORS = [
    ("CSS_SELECTOR", "textarea[placeholder*='输入']"),
    ("CSS_SELECTOR", "textarea"),
    ("CSS_SELECTOR", "input[placeholder*='输入']"),
    ("CSS_SELECTOR", "input[placeholder*='消息']"),
    ("CSS_SELECTOR", "input[placeholder*='问题']"),
    ("CSS_SELECTOR", "div[contenteditable='true']"),
    ("CSS_SELECTOR", ".chat-input textarea"),
    ("CSS_SELECTOR", ".input-area textarea"),
    ("CSS_SELECTOR", "[class*='input'] textarea"),
    ("CSS_SELECTOR", "[class*='chat'] input"),
]

def log(msg):
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] {msg}")

def create_driver():
    common_args = [
        "--no-sandbox",
        "--disable-dev-shm-usage",
        "--disable-gpu",
        "--window-size=1280,800",
    ]

    # 使用独立的浏览器配置文件，登录状态会保留，下次运行就不用重新登录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    profile_dir = os.path.join(script_dir, "browser_profile")
    os.makedirs(profile_dir, exist_ok=True)

    if USE_EDGE:
        log("使用 Edge 浏览器")
        options = EdgeOptions()
        if not BROWSER_VISIBLE:
            options.add_argument("--headless=new")
        for arg in common_args:
            options.add_argument(arg)
        options.add_argument(f"--user-data-dir={profile_dir}")
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option("useAutomationExtension", False)

        if os.path.exists(EDGEDRIVER_PATH):
            log(f"使用本地 EdgeDriver: {EDGEDRIVER_PATH}")
            service = EdgeService(executable_path=EDGEDRIVER_PATH)
        else:
            log("未找到本地 msedgedriver.exe，尝试联网下载...")
            service = EdgeService(EdgeChromiumDriverManager().install())
        driver = webdriver.Edge(service=service, options=options)
    else:
        log("使用 Chrome 浏览器")
        options = webdriver.ChromeOptions()
        if not BROWSER_VISIBLE:
            options.add_argument("--headless=new")
        for arg in common_args:
            options.add_argument(arg)
        options.add_argument(f"--user-data-dir={profile_dir}")
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option("useAutomationExtension", False)

        if os.path.exists(CHROMEDRIVER_PATH):
            log(f"使用本地 ChromeDriver: {CHROMEDRIVER_PATH}")
            service = ChromeService(executable_path=CHROMEDRIVER_PATH)
        else:
            log("未找到本地 ChromeDriver，尝试联网下载...")
            service = ChromeService(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=options)

    driver.execute_cdp_cmd("Page.addScriptToEvaluateOnNewDocument", {
        "source": "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
    })
    return driver

def find_element(driver, selectors, timeout=15):
    """按优先级尝试多个定位方式，返回第一个命中的元素。"""
    for by_name, selector in selectors:
        by = getattr(By, by_name)
        try:
            element = WebDriverWait(driver, timeout).until(
                EC.presence_of_element_located((by, selector))
            )
            return element
        except Exception:
            continue
    return None

def wait_for_login_popup_to_disappear(driver):
    """检测并等待登录弹窗消失。"""
    login_selectors = [
        "._login_warp_o0er6_1",
        ".login-warp",
        ".login_warp",
        "[class*='login_warp']",
        "[class*='login-warp']",
        ".ant-modal-wrap",
        ".ant-modal-mask",
    ]
    popup = None
    found_selector = None
    for selector in login_selectors:
        try:
            popup = driver.find_element(By.CSS_SELECTOR, selector)
            if popup.is_displayed():
                found_selector = selector
                break
            popup = None
        except Exception:
            continue

    if popup is None:
        return True

    log(f"检测到登录弹窗，请在 {LOGIN_TIMEOUT_SECONDS} 秒内完成登录...")
    try:
        WebDriverWait(driver, LOGIN_TIMEOUT_SECONDS).until_not(
            EC.presence_of_element_located((By.CSS_SELECTOR, found_selector))
        )
        log("登录弹窗已消失，继续执行")
        time.sleep(1)
        return True
    except Exception:
        log("等待登录超时")
        return False

def send_message(driver):
    """在页面中找到输入框并发送消息。"""
    time.sleep(3)

    # 如果有登录弹窗，先等用户登录
    if not wait_for_login_popup_to_disappear(driver):
        return False

    input_box = find_element(driver, INPUT_SELECTORS)
    if input_box is None:
        log("未能找到聊天输入框，请检查 INPUT_SELECTORS 中的选择器是否匹配页面元素")
        return False

    # 聚焦并输入消息
    input_box.click()
    input_box.clear()
    input_box.send_keys(MESSAGE)
    log(f"已输入消息: {MESSAGE}")
    time.sleep(0.5)

    # 直接按回车发送（该网站支持回车发送，最稳定）
    try:
        input_box.send_keys(Keys.RETURN)
        log("已按回车发送")
        return True
    except Exception as e:
        log(f"回车发送失败: {e}")
        return False

def run_once():
    driver = None
    try:
        log("启动浏览器...")
        driver = create_driver()
        driver.get(CHAT_URL)
        log(f"已打开页面: {CHAT_URL}")

        if send_message(driver):
            log(f"等待 {WAIT_AFTER_SEND_SECONDS} 秒后关闭...")
            time.sleep(WAIT_AFTER_SEND_SECONDS)
        else:
            log("消息发送失败，30 秒后关闭浏览器")
            time.sleep(30)
    except Exception as e:
        log(f"运行出错: {e}")
        time.sleep(30)
    finally:
        if driver:
            try:
                driver.quit()
                log("浏览器已关闭")
            except Exception as e:
                log(f"关闭浏览器时出错: {e}")

def main():
    log("脚本已启动，按 Ctrl+C 停止")
    while True:
        run_once()
        log(f"下次执行将在 {INTERVAL_SECONDS} 秒后")
        time.sleep(INTERVAL_SECONDS)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log("用户手动停止脚本")
        sys.exit(0)
