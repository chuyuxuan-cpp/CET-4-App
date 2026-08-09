#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从 mahavivo/english-wordlists 开源词库生成 CET-4/6 SQLite 数据库。

词库来源: https://github.com/mahavivo/english-wordlists
- CET4_edited.txt: 大学英语四级大纲单词表 (4,547 词)
- CET6_edited.txt: 大学英语六级大纲单词表 (2,266 词)

输入格式 (每行一词):
    word [phonetic] pos. meaning
    abandon [əˈbændən] vt.丢弃；放弃，抛弃

输出: assets/cet4.db
表: words (id, word, phonetic, pos, meaning, example, book, seq)
- book: 'cet4' or 'cet6'
- example: 缺失（开源词表不含例句），后续可补充
"""

import sqlite3
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
ASSETS_DIR = os.path.join(PROJECT_DIR, 'assets')
DB_PATH = os.path.join(ASSETS_DIR, 'cet4.db')


def parse_word_line(line: str, book: str, seq: int) -> dict | None:
    """
    解析一行词条，格式:
        word [phonetic] pos. meaning
    例如:
        abandon [əˈbændən] vt.丢弃；放弃，抛弃
        a art.一(个)；每一(个)  (无音标)
    """
    line = line.strip()
    if not line or line[0].isascii() and not line[0].isalpha():
        return None

    # 匹配: word [phonetic] rest
    # 或: word rest (无音标)
    m = re.match(r'^(\S+)\s+(?:\[([^\]]+)\]\s+)?(.+)$', line)
    if not m:
        return None

    word = m.group(1).strip()
    phonetic = m.group(2)
    rest = m.group(3).strip()

    # 解析词性和释义
    # 常见格式: "n.能力；能耐"，"vt.&vi.出产"，"v. 1. 抛弃 2. 离弃"
    pos_match = re.match(
        r'^((?:[a-z]+\.\s*(?:&[a-z]+\.\s*)?)+|art\.)\s*(.+)',
        rest, re.IGNORECASE
    )
    if pos_match:
        pos = pos_match.group(1).strip()
        meaning = pos_match.group(2).strip()
    else:
        # 无法解析词性，把整段当释义
        pos = ''
        meaning = rest

    # 清理：去掉释义里的编号 "1. 2. 3."
    meaning = re.sub(r'\d+\.\s*', '', meaning).strip()
    # 合并多余空格
    meaning = re.sub(r'\s+', ' ', meaning)

    return {
        'word': word,
        'phonetic': f'/{phonetic}/' if phonetic else None,
        'pos': pos,
        'meaning': meaning,
        'book': book,
        'seq': seq,
    }


def parse_file(filepath: str, book: str) -> list[dict]:
    """解析整个词表文件，返回词条列表。"""
    entries = []
    seq = 0
    with open(filepath, 'r', encoding='utf-8-sig') as f:
        for line in f:
            entry = parse_word_line(line, book, seq)
            if entry:
                entries.append(entry)
                seq += 1
    return entries


def create_database(cet4_entries: list[dict], cet6_entries: list[dict]):
    """创建 SQLite 数据库并写入词条。"""
    os.makedirs(ASSETS_DIR, exist_ok=True)

    existing_examples = {}
    if os.path.exists(DB_PATH):
        previous = sqlite3.connect(DB_PATH)
        try:
            existing_examples = {
                (word.lower(), book): example
                for word, book, example in previous.execute(
                    "SELECT word, book, example FROM words WHERE example IS NOT NULL AND example != ''"
                )
            }
        finally:
            previous.close()
        os.remove(DB_PATH)

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    # Keep the seed database schema identical to AppDatabase so it can be
    # copied directly to the application's writable Drift database location.
    c.executescript('''
        CREATE TABLE words (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT NOT NULL CHECK (length(word) >= 1 AND length(word) <= 100),
            phonetic TEXT,
            pos TEXT,
            meaning TEXT,
            example TEXT,
            book TEXT NOT NULL DEFAULT 'cet4',
            seq INTEGER NOT NULL
        );

        CREATE TABLE progress (
            word_id INTEGER NOT NULL REFERENCES words (id),
            book TEXT NOT NULL DEFAULT 'cet4',
            first_learned_at INTEGER,
            stage INTEGER NOT NULL DEFAULT 1,
            next_review_at INTEGER,
            PRIMARY KEY (word_id, book)
        );

        CREATE TABLE notebook (
            word_id INTEGER NOT NULL REFERENCES words (id),
            added_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            source TEXT NOT NULL DEFAULT 'manual',
            PRIMARY KEY (word_id)
        );

        CREATE TABLE quiz_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            answered_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
            word_id INTEGER NOT NULL REFERENCES words (id),
            quiz_type TEXT NOT NULL,
            direction TEXT NOT NULL,
            correct INTEGER NOT NULL CHECK (correct IN (0, 1))
        );

        CREATE TABLE settings (
            key TEXT NOT NULL PRIMARY KEY,
            value TEXT NOT NULL
        );
    ''')

    all_entries = cet4_entries + cet6_entries
    for entry in all_entries:
        entry['example'] = existing_examples.get((entry['word'].lower(), entry['book']))

    c.executemany('''
        INSERT INTO words (word, phonetic, pos, meaning, example, book, seq)
        VALUES (:word, :phonetic, :pos, :meaning, :example, :book, :seq)
    ''', all_entries)

    # 索引
    c.execute('CREATE INDEX idx_word ON words(word)')
    c.execute('CREATE INDEX idx_book ON words(book)')
    c.execute('CREATE INDEX idx_seq ON words(seq)')
    c.execute('CREATE INDEX idx_book_seq ON words(book, seq)')

    conn.commit()
    conn.close()


def verify():
    """验证数据库内容。"""
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()

    c.execute("SELECT COUNT(*) FROM words")
    total = c.fetchone()[0]
    print(f'总词数: {total}')

    c.execute("SELECT book, COUNT(*) FROM words GROUP BY book")
    for book, count in c.fetchall():
        print(f'  {book}: {count}')

    print(f'\nCET-4 前 10 词:')
    c.execute("SELECT word, phonetic, pos, meaning FROM words WHERE book='cet4' ORDER BY seq LIMIT 10")
    for row in c.fetchall():
        print(f'  {row[0]:15s} {row[1] or "(无音标)":25s} {row[2]:15s} {row[3]}')

    print(f'\nCET-4 末 5 词:')
    c.execute("SELECT word, phonetic, pos, meaning FROM words WHERE book='cet4' ORDER BY seq DESC LIMIT 5")
    for row in c.fetchall():
        print(f'  {row[0]:15s} {row[1] or "(无音标)":25s} {row[2]:15s} {row[3]}')

    print(f'\nCET-6 前 5 词:')
    c.execute("SELECT word, phonetic, pos, meaning FROM words WHERE book='cet6' ORDER BY seq LIMIT 5")
    for row in c.fetchall():
        print(f'  {row[0]:15s} {row[1] or "(无音标)":25s} {row[2]:15s} {row[3]}')

    # 检查音标覆盖率
    c.execute("SELECT COUNT(*) FROM words WHERE phonetic IS NOT NULL")
    has_phonetic = c.fetchone()[0]
    print(f'\n音标覆盖率: {has_phonetic}/{total} ({has_phonetic*100//total}%)')

    conn.close()


def main():
    cet4_path = os.path.join(SCRIPT_DIR, 'CET4_edited.txt')
    cet6_path = os.path.join(SCRIPT_DIR, 'CET6_edited.txt')

    if not os.path.exists(cet4_path):
        print(f'错误: 找不到 {cet4_path}')
        print('请先运行: curl -o tools/CET4_edited.txt https://raw.githubusercontent.com/mahavivo/english-wordlists/master/CET4_edited.txt')
        sys.exit(1)
    if not os.path.exists(cet6_path):
        print(f'错误: 找不到 {cet6_path}')
        sys.exit(1)

    print('解析 CET-4 词表...')
    cet4_entries = parse_file(cet4_path, 'cet4')
    print(f'  → {len(cet4_entries)} 个词条')

    print('解析 CET-6 词表...')
    cet6_entries = parse_file(cet6_path, 'cet6')
    print(f'  → {len(cet6_entries)} 个词条')

    print('生成数据库...')
    create_database(cet4_entries, cet6_entries)

    print('\n验证数据库:')
    verify()

    print(f'\n数据库已生成: {DB_PATH}')
    print(f'文件大小: {os.path.getsize(DB_PATH) / 1024:.1f} KB')


if __name__ == '__main__':
    main()
