# load_test_api.py
# Скрипт нагрузочного тестирования API с замером утилизации GPU

import requests
import time
import statistics
import glob
import json
import os
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import numpy as np

# ===================== НАСТРОЙКИ =====================
API_URL = "http://localhost:4000/api/classify"   # IP Mac
STATUS_URL = "http://localhost:4000/api/status/{}"

IMAGES_DIR = "test_images"
CONCURRENCY_LEVELS = [1, 2, 4, 8]
TEST_REQUESTS_PER_CONCURRENCY = 30
REQUEST_TIMEOUT = 180
STATUS_POLL_INTERVAL = 0.1
STATUS_MAX_WAIT = 180
# ======================================================

gpu_metrics = []
gpu_monitoring = True

def get_gpu_utilization():
    """Возвращает utilisation.gpu и memory.used через nvidia-smi."""
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            parts = result.stdout.strip().split(", ")
            if len(parts) == 2:
                return float(parts[0]), float(parts[1])
    except:
        pass
    return 0.0, 0.0

def gpu_monitor_loop(interval=0.5):
    """Фоновый поток для периодического опроса GPU."""
    global gpu_metrics, gpu_monitoring
    while gpu_monitoring:
        util, mem = get_gpu_utilization()
        gpu_metrics.append((util, mem))
        time.sleep(interval)

def wait_for_result(job_id):
    start_time = time.time()
    while time.time() - start_time < STATUS_MAX_WAIT:
        try:
            resp = requests.get(STATUS_URL.format(job_id), timeout=5)
            if resp.status_code == 200:
                data = resp.json()
                if data.get("status") == "completed":
                    return data.get("result")
                elif data.get("status") == "error":
                    return None
        except:
            pass
        time.sleep(STATUS_POLL_INTERVAL)
    return None

def load_test_images():
    images = []
    for ext in ["*.jpg", "*.jpeg", "*.png"]:
        images.extend(glob.glob(os.path.join(IMAGES_DIR, ext)))
        images.extend(glob.glob(ext))
    if not images:
        print(f"❌ Нет изображений в папке '{IMAGES_DIR}' или в текущей директории.")
    return images[:5]

def send_request(image_path):
    start = time.time()
    try:
        with open(image_path, "rb") as f:
            files = {"image": (os.path.basename(image_path), f, "image/jpeg")}
            resp = requests.post(API_URL, files=files, timeout=REQUEST_TIMEOUT)
            if resp.status_code != 200:
                return None
            data = resp.json()
            if not data.get("success"):
                return None
            result = wait_for_result(data.get("job_id"))
            if result:
                return time.time() - start, result.get("processing_time_ms", 0)
    except Exception as e:
        print(f"  Ошибка: {e}")
    return None

def run():
    global gpu_metrics, gpu_monitoring
    print("=" * 70)
    print("🚀 РАСПРЕДЕЛЁННЫЙ НАГРУЗОЧНЫЙ ТЕСТ (с замером GPU)")
    print("=" * 70)

    images = load_test_images()
    if not images:
        return

    print(f"📸 Тестовых изображений: {len(images)}")
    print(f"🌐 API: {API_URL}")
    print("")

    results = {}

    for concurrency in CONCURRENCY_LEVELS:
        print(f"⚡ Конкурентность: {concurrency}")

        # Запускаем мониторинг GPU
        gpu_metrics = []
        gpu_monitoring = True
        monitor_thread = threading.Thread(target=gpu_monitor_loop, daemon=True)
        monitor_thread.start()

        total_times = []
        inference_times = []
        successful = 0

        with ThreadPoolExecutor(max_workers=concurrency) as ex:
            futures = [ex.submit(send_request, images[i % len(images)])
                      for i in range(TEST_REQUESTS_PER_CONCURRENCY)]

            for future in as_completed(futures):
                res = future.result()
                if res:
                    total_times.append(res[0])
                    inference_times.append(res[1])
                    successful += 1

        # Останавливаем мониторинг GPU
        gpu_monitoring = False
        monitor_thread.join(timeout=2)

        # Считаем среднюю и пиковую утилизацию
        if gpu_metrics:
            utils = [m[0] for m in gpu_metrics]
            mems = [m[1] for m in gpu_metrics]
            avg_gpu_util = round(statistics.mean(utils), 1)
            peak_gpu_util = round(max(utils), 1)
            avg_gpu_mem = round(statistics.mean(mems), 0)
        else:
            avg_gpu_util = 0
            peak_gpu_util = 0
            avg_gpu_mem = 0

        if total_times:
            avg_total = statistics.mean(total_times) * 1000
            p99_total = np.percentile(total_times, 99) * 1000
            avg_inf = statistics.mean(inference_times)
            p99_inf = np.percentile(inference_times, 99)
            rps = successful / sum(total_times)

            results[concurrency] = {
                "success": successful,
                "total": TEST_REQUESTS_PER_CONCURRENCY,
                "avg_total_ms": round(avg_total, 2),
                "p99_total_ms": round(p99_total, 2),
                "avg_inference_ms": round(avg_inf, 2),
                "p99_inference_ms": round(p99_inf, 2),
                "rps": round(rps, 2),
                "avg_gpu_util": avg_gpu_util,
                "peak_gpu_util": peak_gpu_util,
                "avg_gpu_mem": avg_gpu_mem
            }

            print(f"  ✅ Успешно: {successful}/{TEST_REQUESTS_PER_CONCURRENCY}")
            print(f"  ⏱️  Среднее полное время: {avg_total:.2f} мс")
            print(f"  ⚡ Среднее инференс: {avg_inf:.2f} мс")
            print(f"  🚀 RPS: {rps:.1f}")
            print(f"  🎮 Средняя утилизация GPU: {avg_gpu_util}%")
            print(f"  📈 Пиковая утилизация GPU: {peak_gpu_util}%")
            print(f"  💾 Средняя память GPU: {avg_gpu_mem} MB\n")
        else:
            print("  ❌ Все запросы провалились\n")

    print("\n📊 ИТОГОВАЯ ТАБЛИЦА")
    print("=" * 120)
    print("| Conc | RPS | Total avg | p99 total | Inf avg | p99 inf | GPU avg | GPU peak | GPU mem |")
    print("|------|-----|-----------|-----------|---------|---------|---------|----------|---------|")
    for c, r in results.items():
        print(f"| {c:<4} | {r['rps']:<3} | {r['avg_total_ms']:<9} | {r['p99_total_ms']:<9} | {r['avg_inference_ms']:<7} | {r['p99_inference_ms']:<7} | {r['avg_gpu_util']:<7} | {r['peak_gpu_util']:<8} | {r['avg_gpu_mem']:<7} |")
    print("=" * 120)

    with open("distributed_test_results.json", "w") as f:
        json.dump(results, f, indent=2)

if __name__ == "__main__":
    try:
        requests.get(API_URL.replace("/api/classify", ""), timeout=3)
        print("✅ Веб-узел доступен\n")
    except:
        print("❌ Веб-узел недоступен. Проверь IP и порт.")
        exit(1)

    run()
