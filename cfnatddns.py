import subprocess
import re
import yaml
import requests
import ipaddress
import os
import shutil
import tempfile
import sys
import atexit
import signal
import threading
from datetime import datetime
from PIL import Image
import pystray
from pystray import MenuItem as item
import win32gui
import win32con
import win32console

exe_name = "cfnat-windows-amd64.exe"
log_file = "cfnat_log.txt"
config_file = "config.yaml"

# -------------------- 清理旧的 _MEIxxxx 临时目录 --------------------
def cleanup_mei_dirs():
    temp_dir = tempfile.gettempdir()
    current_dir = getattr(sys, '_MEIPASS', None)
    for item in os.listdir(temp_dir):
        path = os.path.join(temp_dir, item)
        if item.startswith("_MEI") and os.path.isdir(path):
            if current_dir and os.path.abspath(path) == os.path.abspath(current_dir):
                continue
            try:
                shutil.rmtree(path)
                print(f"[清理] 删除残留: {path}")
            except Exception as e:
                print(f"[跳过] 删除失败 {path}: {e}")

cleanup_mei_dirs()

# -------------------- Ctrl+C 信号处理 --------------------
def signal_handler(sig, frame):
    print("\n[退出] 收到中断信号，正在退出...")
    try:
        proc.terminate()
    except Exception:
        pass
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# -------------------- 读取配置 --------------------
try:
    with open(config_file, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)
except Exception as e:
    print(f"[错误] 配置读取失败: {e}")
    exit(1)

# Modified: Expect cloudflare to be a single dictionary, with record_names as a list
cf_conf = config.get("cloudflare", {})
cf_email = cf_conf.get("email")
cf_api_key = cf_conf.get("api_key")
cf_zone_id = cf_conf.get("zone_id")
cf_record_names = cf_conf.get("record_names", []) # Now expecting a list of names

# Basic validation for Cloudflare config
if not all([cf_email, cf_api_key, cf_zone_id, cf_record_names]):
    print("[错误] Cloudflare 配置不完整 (email, api_key, zone_id, 或 record_names 缺失)。请检查 config.yaml。")
    exit(1)
if not isinstance(cf_record_names, list):
    print("[错误] Cloudflare 'record_names' 应为列表。请检查 config.yaml。")
    exit(1)

sync_count = config.get("sync_count", 1)

# -------------------- IP 工具 --------------------
ipv4_pattern = re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")
ipv6_pattern = re.compile(r"\b(?:[a-fA-F0-9]{1,4}:){2,7}[a-fA-F0-9]{1,4}\b")

def get_ip_type(ip):
    try:
        ip_obj = ipaddress.ip_address(ip)
        return "A" if ip_obj.version == 4 else "AAAA"
    except ValueError:
        return None

# -------------------- IP 缓存初始化与保存 --------------------
ip_cache = {"A": [], "AAAA": []}
log_data = []

def load_ip_log():
    if not os.path.exists(log_file):
        return
    with open(log_file, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                time_part, ip = line[:19], line[20:]
                rtype = get_ip_type(ip)
                if rtype and ip not in ip_cache[rtype]:
                    log_data.append((time_part, ip))
                    ip_cache[rtype].append(ip)
            except Exception:
                continue

    # 按照时间戳排序，并确保缓存的数量不超过 sync_count
    ip_cache["A"] = sorted(ip_cache["A"], key=lambda x: x[0])[:sync_count]  # 按时间戳排序并限制数量
    ip_cache["AAAA"] = sorted(ip_cache["AAAA"], key=lambda x: x[0])[:sync_count]  # 同上
    log_data[:] = [entry for entry in log_data if entry[1] in ip_cache["A"] + ip_cache["AAAA"]]  # 只保留缓存中的 IP

def save_ip_log():
    all_lines = []
    # 仅保存缓存中存在的 IP
    for rtype in ["A", "AAAA"]:
        for ip in ip_cache[rtype]:
            for time_str, cached_ip in reversed(log_data):
                if cached_ip == ip:
                    all_lines.append(f"{time_str} {ip}")
                    break
    with open(log_file, "w", encoding="utf-8") as f:
        f.write("\n".join(all_lines) + "\n")

load_ip_log()

# -------------------- Cloudflare 同步函数 --------------------
def update_cf_dns(ip, cf_email, cf_api_key, cf_zone_id, cf_record_name):
    record_type = get_ip_type(ip)
    if not record_type:
        print(f"[跳过] 非法 IP 地址: {ip} for {cf_record_name}")
        return

    other_type = "AAAA" if record_type == "A" else "A"
    
    # Step 1: Delete records of the *other* type if they exist for this specific record_name
    try:
        del_params = {"type": other_type, "name": cf_record_name}
        url = f"https://api.cloudflare.com/client/v4/zones/{cf_zone_id}/dns_records"
        del_resp = requests.get(url, headers={
            "X-Auth-Email": cf_email,
            "X-Auth-Key": cf_api_key,
            "Content-Type": "application/json"
        }, params=del_params)
        
        if del_resp.json().get("success"):
            for record in del_resp.json().get("result", []):
                record_id = record["id"]
                requests.delete(f"{url}/{record_id}", headers={
                    "X-Auth-Email": cf_email,
                    "X-Auth-Key": cf_api_key,
                    "Content-Type": "application/json"
                })
                print(f"[{cf_record_name}] 清除旧 {other_type} 记录: {record['content']}")
        elif not del_resp.json().get("success"):
            print(f"[{cf_record_name}] 查询旧 {other_type} 记录失败或无权限: {del_resp.json()}")
    except Exception as e:
        print(f"[{cf_record_name}] 删除 {other_type} 记录异常: {e}")

    # Step 2: Synchronize records of the *current* type
    try:
        params = {"type": record_type, "name": cf_record_name}
        resp = requests.get(url, headers={
            "X-Auth-Email": cf_email,
            "X-Auth-Key": cf_api_key,
            "Content-Type": "application/json"
        }, params=params)
        
        existing = resp.json().get("result", []) if resp.json().get("success") else []
        existing_ips = {r["content"]: r["id"] for r in existing}
        desired_ips = ip_cache[record_type]  # Use the global IP cache for the current type

        # Delete any existing records that are no longer in our desired list
        for ip_val, r_id in existing_ips.items():
            if ip_val not in desired_ips:
                requests.delete(f"{url}/{r_id}", headers={
                    "X-Auth-Email": cf_email,
                    "X-Auth-Key": cf_api_key,
                    "Content-Type": "application/json"
                })
                print(f"[{cf_record_name}] 同步删除多余 {record_type} IP: {ip_val}")

        # Add any desired IPs that don't currently exist
        for ip_val in desired_ips:
            if ip_val in existing_ips:
                continue  # Already exists
            data = {
                "type": record_type,
                "name": cf_record_name,
                "content": ip_val,
                "ttl": 1,  # Automatic TTL
                "proxied": False  # Not proxied by default
            }
            resp = requests.post(url, headers={
                "X-Auth-Email": cf_email,
                "X-Auth-Key": cf_api_key,
                "Content-Type": "application/json"
            }, json=data)
            if resp.json().get("success"):
                print(f"[{cf_record_name}] 添加 {record_type} IP 成功: {ip_val}")
            else:
                print(f"[{cf_record_name}] 添加 {record_type} IP 失败: {resp.json()}")
    except Exception as e:
        print(f"[{cf_record_name}] 同步 {record_type} 记录异常: {e}")

# -------------------- 启动 cfnat 子进程 --------------------
args = [exe_name]
optional_args = {
    "colo": "-colo=",
    "port": "-port=",
    "addr": "-addr=",
    "ips": "-ips=",
    "delay": "-delay=",
    "ipnum": "-ipnum=",
    "num": "-num=",
    "task": "-task="
}
for key, flag in optional_args.items():
    value = config.get(key)
    if value is not None:  # Use config directly, not cf_conf, for general cfnat args
        args.append(f"{flag}{value}")

try:
    proc = subprocess.Popen(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="ignore",
        bufsize=1
    )
except Exception as e:
    print(f"[错误] 启动失败: {e}")
    exit(1)

# -------------------- 托盘图标控制台 --------------------
console_hwnd = win32console.GetConsoleWindow()

def toggle_console():
    if win32gui.IsWindowVisible(console_hwnd):
        win32gui.ShowWindow(console_hwnd, win32con.SW_HIDE)
    else:
        win32gui.ShowWindow(console_hwnd, win32con.SW_SHOW)

def on_show_hide(icon, item): toggle_console()
def on_exit(icon, item):
    icon.stop()
    try:
        proc.terminate()
    except Exception:
        pass
    os._exit(0)

def tray_icon():
    try:
        image = Image.open("icon.ico")
    except Exception as e:
        print(f"[错误] 无法加载托盘图标: {e}")
        return
    tray_title = os.path.basename(sys.argv[0])
    menu = (item('显示/隐藏', on_show_hide), item('控制台退出', on_exit))
    pystray.Icon("cfnat", image, tray_title, menu).run()

threading.Thread(target=tray_icon, daemon=True).start()

# -------------------- 实时监听输出并更新 IP --------------------
for line in proc.stdout:
    line = line.strip()
    print(line)
    if "最佳" in line or "best" in line.lower():
        ips = ipv4_pattern.findall(line) + ipv6_pattern.findall(line)
        for ip in ips:
            # This specific filter might be excluding valid IPv6 IPs like ::1 or certain short forms.
            # If you encounter issues with IPv6 updates, review this filter.
            if ":" in ip and ip.count(":") == 2 and ip.replace(":", "").isdigit():
                continue
            rtype = get_ip_type(ip)
            if rtype and ip not in ip_cache[rtype]:
                ip_cache[rtype].insert(0, ip)
                ip_cache[rtype] = ip_cache[rtype][:sync_count]  # 确保缓存的 IP 数量不超过 sync_count
                timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                log_data.insert(0, (timestamp, ip))
                # 只保留缓存中的 IP
                log_data[:] = [entry for entry in log_data if entry[1] in ip_cache["A"] + ip_cache["AAAA"]]
                save_ip_log()
                print(f"[更新] 检测到新 {rtype} IP: {ip}")
                
                # Modified: Iterate through all configured record_names for the single CF account/zone
                for record_name_item in cf_record_names:
                    # Start a thread to update DNS for each record_name
                    threading.Thread(target=update_cf_dns, args=(ip, cf_email, cf_api_key, cf_zone_id, record_name_item,), daemon=True).start()
