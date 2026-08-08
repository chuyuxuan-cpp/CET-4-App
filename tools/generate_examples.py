#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
调用 DeepSeek API 为 CET-4/6 词库批量生成例句。
每次请求处理一批单词（batch mode），减少 API 调用次数。

用法：
    # 设置 API Key
    set DEEPSEEK_API_KEY=sk-xxx

    # 运行（默认每批 20 词，每次间隔 1 秒）
    python tools/generate_examples.py

    # 自定义批大小和延迟
    python tools/generate_examples.py --batch-size 30 --delay 2

输出：直接更新 assets/cet4.db 中 words 表的 example 列。
"""

import sqlite3
import os
import sys
import json
import time
import argparse
import urllib.request
import urllib.error

# Windows 控制台 UTF-8 编码修复
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# ============================================================================
# Config
# ============================================================================

DEEPSEEK_API_URL = "https://api.deepseek.com/chat/completions"
MODEL = "deepseek-chat"  # DeepSeek-V3
DB_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "cet4.db")
CHECKPOINT_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "example_checkpoint.txt")

SYSTEM_PROMPT = """You are an English teacher creating example sentences for Chinese students learning English (CET-4 level).

For each word below, write ONE natural, useful English example sentence. The sentence should:
1. Use the word in a common, everyday context
2. Be 5-15 words long
3. Avoid complex vocabulary beyond CET-4 level
4. Be appropriate for Chinese college students

Return ONLY a JSON array of objects. Each object must have exactly two fields:
- "word": the English word (exactly as given)
- "example": the example sentence

Example output:
[
  {"word": "abandon", "example": "They had to abandon the plan due to bad weather."},
  {"word": "ability", "example": "She has a natural ability to make people feel comfortable."}
]

Return ONLY the JSON array, no other text."""


def get_api_key() -> str:
    """从环境变量或 .env 文件获取 API Key。"""
    key = os.environ.get("DEEPSEEK_API_KEY", "")
    if key:
        return key

    # 尝试从项目根目录 .env 读取
    env_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
    if os.path.exists(env_file):
        with open(env_file, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line.startswith("DEEPSEEK_API_KEY="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")

    print("错误: 未找到 DEEPSEEK_API_KEY。请设置环境变量或在项目根目录创建 .env 文件。")
    print("  set DEEPSEEK_API_KEY=sk-xxx")
    print("  或")
    print("  在 E:\\CET-4 App\\.env 中写入: DEEPSEEK_API_KEY=sk-xxx")
    sys.exit(1)


def load_words_to_process(db_path: str) -> list[dict]:
    """从数据库加载所有需要例句的单词（example 为空或为 NULL）。"""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT id, word, meaning, book FROM words WHERE example IS NULL OR example = '' ORDER BY book, seq")
    rows = [dict(r) for r in c.fetchall()]
    conn.close()
    return rows


def load_checkpoint() -> set[int]:
    """加载已处理的 word id 集合。"""
    if not os.path.exists(CHECKPOINT_FILE):
        return set()
    with open(CHECKPOINT_FILE, "r", encoding="utf-8") as f:
        return {int(line.strip()) for line in f if line.strip().isdigit()}


def save_checkpoint(word_ids: list[int]):
    """追加已处理的 word id 到断点文件。"""
    with open(CHECKPOINT_FILE, "a", encoding="utf-8") as f:
        for wid in word_ids:
            f.write(f"{wid}\n")


def call_deepseek(api_key: str, words: list[dict]) -> list[dict] | None:
    """调用 DeepSeek API 为一组单词生成例句。"""
    word_list = [w["word"] for w in words]
    user_message = "Generate example sentences for these words:\n" + "\n".join(
        f"- {w['word']} ({w['meaning']})" for w in words
    )

    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_message},
        ],
        "temperature": 0.7,
        "max_tokens": min(len(words) * 60, 4096),
        "response_format": {"type": "json_object"},
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(DEEPSEEK_API_URL, data=data)
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", f"Bearer {api_key}")

    max_retries = 3
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                body = json.loads(resp.read().decode("utf-8"))
                content = body["choices"][0]["message"]["content"]

                # Parse JSON from response
                # The response may contain markdown code blocks
                content = content.strip()
                if content.startswith("```"):
                    # Strip markdown code fences
                    lines = content.split("\n")
                    content = "\n".join(lines[1:-1])

                results = json.loads(content)
                if isinstance(results, dict):
                    # Sometimes the model wraps in an object, try finding the array
                    for v in results.values():
                        if isinstance(v, list):
                            results = v
                            break

                if not isinstance(results, list):
                    print(f"  ⚠ 预期数组，收到 {type(results).__name__}，跳过此批")
                    return None

                # Extract examples
                examples = []
                for item in results:
                    if isinstance(item, dict) and "example" in item:
                        w = item.get("word", "").strip().lower()
                        ex = item.get("example", "").strip()
                        if ex:
                            examples.append({"word_lower": w, "example": ex})

                return examples if examples else None

        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            print(f"  ⚠ HTTP {e.code}: {body[:300]}")
            if e.code == 429:
                wait = 10 * (attempt + 1)
                print(f"  速率限制，等待 {wait}s...")
                time.sleep(wait)
            elif e.code >= 500:
                time.sleep(5 * (attempt + 1))
            else:
                return None
        except (json.JSONDecodeError, KeyError, IndexError) as e:
            print(f"  ⚠ 解析响应失败: {e}")
            if attempt < max_retries - 1:
                time.sleep(3)
        except Exception as e:
            print(f"  ⚠ 请求失败: {e}")
            if attempt < max_retries - 1:
                time.sleep(5)

    return None


def update_database(db_path: str, examples: list[dict]):
    """将例句写入数据库。"""
    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    updated = 0
    for ex in examples:
        # Match by lowercase word
        c.execute(
            "UPDATE words SET example = ? WHERE LOWER(word) = ? AND (example IS NULL OR example = '')",
            (ex["example"], ex["word_lower"])
        )
        if c.rowcount > 0:
            updated += 1

    conn.commit()
    conn.close()
    return updated


def main():
    parser = argparse.ArgumentParser(description="用 DeepSeek API 为 CET-4/6 词库生成例句")
    parser.add_argument("--batch-size", type=int, default=20, help="每批单词数 (默认 20)")
    parser.add_argument("--delay", type=float, default=1.0, help="每批之间延迟秒数 (默认 1)")
    parser.add_argument("--limit", type=int, default=0, help="最多处理多少词 (0=全部)")
    parser.add_argument("--dry-run", action="store_true", help="只预览不调用 API")
    args = parser.parse_args()

    api_key = get_api_key()

    print(f"加载词库...")
    all_words = load_words_to_process(DB_PATH)
    checkpoint = load_checkpoint()

    # Filter out already processed
    pending = [w for w in all_words if w["id"] not in checkpoint]

    if args.limit > 0:
        pending = pending[:args.limit]

    print(f"总需处理: {len(pending)} 词 (已完成: {len(checkpoint)})")
    print(f"批大小: {args.batch_size}, API: {MODEL}")
    print()

    if args.dry_run or not pending:
        print("预览（前 30 词）:")
        for w in pending[:30]:
            print(f"  #{w['id']:5d}  {w['word']:20s}  {w['meaning'][:40]}")
        return

    total_updated = 0
    total_cost_est = 0

    for i in range(0, len(pending), args.batch_size):
        batch = pending[i:i + args.batch_size]
        batch_num = i // args.batch_size + 1
        total_batches = (len(pending) + args.batch_size - 1) // args.batch_size

        print(f"[{batch_num}/{total_batches}] 生成 {len(batch)} 词...", end=" ", flush=True)

        result = call_deepseek(api_key, batch)

        if result:
            updated = update_database(DB_PATH, result)
            save_checkpoint([w["id"] for w in batch])
            total_updated += updated

            # Estimate cost: ~$0.14/1M input, ~$0.28/1M output for DeepSeek-V3
            batch_input_tokens = len(SYSTEM_PROMPT) // 4 + sum(len(w["word"]) + len(w["meaning"]) for w in batch) // 4
            batch_cost_est = (batch_input_tokens / 1_000_000) * 0.14 + (len(batch) * 40 / 1_000_000) * 0.28
            total_cost_est += batch_cost_est

            print(f"✔ 写入 {updated} 条 (~${batch_cost_est:.4f})")
        else:
            print("✗ 失败，继续下一批")

        # Respect rate limits
        if batch_num < total_batches:
            time.sleep(args.delay)

    print(f"\n{'='*50}")
    print(f"完成！共更新 {total_updated} 条例句")
    print(f"估算费用: ~${total_cost_est:.4f} (约 ¥{total_cost_est * 7.2:.2f})")

    # Show some examples
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("SELECT word, example FROM words WHERE example IS NOT NULL AND example != '' ORDER BY RANDOM() LIMIT 5")
    print("\n随机抽查 5 条:")
    for word, example in c.fetchall():
        print(f"  {word}: {example}")
    conn.close()


if __name__ == "__main__":
    main()
