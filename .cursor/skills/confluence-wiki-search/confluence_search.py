#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Семантический поиск по Confluence через n8n webhook."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

DEFAULT_URL = "https://n8n-dev.centrofinans.ru/webhook/confluence-search"
DEFAULT_TIMEOUT_SEC = 90


def _eprint(msg: str) -> None:
    print(msg, file=sys.stderr)


def search(query: str, *, api_key: str, url: str, timeout: int) -> str:
    body = json.dumps({"query": query}, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "X-API-KEY": api_key,
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Поиск по корпоративной wiki Confluence (n8n webhook)",
    )
    parser.add_argument(
        "query",
        nargs="?",
        help="поисковая строка",
    )
    parser.add_argument(
        "--query",
        "-q",
        dest="query_opt",
        help="поисковая строка (альтернатива позиционному аргументу)",
    )
    parser.add_argument(
        "--url",
        default=os.environ.get("CONFLUENCE_SEARCH_URL", DEFAULT_URL),
        help=f"URL webhook (по умолчанию: {DEFAULT_URL})",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("CONFLUENCE_SEARCH_API_KEY", ""),
        help="ключ X-API-KEY (или переменная CONFLUENCE_SEARCH_API_KEY)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=int(os.environ.get("CONFLUENCE_SEARCH_TIMEOUT_SEC", DEFAULT_TIMEOUT_SEC)),
        help=f"таймаут запроса в секундах (по умолчанию: {DEFAULT_TIMEOUT_SEC})",
    )
    args = parser.parse_args()

    query = (args.query_opt or args.query or "").strip()
    if not query:
        _eprint("Ошибка: укажите поисковую строку (аргумент или --query).")
        return 2

    api_key = (args.api_key or "").strip()
    if not api_key:
        _eprint(
            "Ошибка: задайте CONFLUENCE_SEARCH_API_KEY или передайте --api-key.",
        )
        return 2

    try:
        result = search(query, api_key=api_key, url=args.url, timeout=args.timeout)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        _eprint(f"HTTP {exc.code}: {body or exc.reason}")
        return 1
    except urllib.error.URLError as exc:
        _eprint(f"Ошибка сети: {exc.reason}")
        return 1
    except TimeoutError:
        _eprint(f"Таймаут ({args.timeout} с). Повторите запрос.")
        return 1

    sys.stdout.write(result)
    if not result.endswith("\n"):
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
