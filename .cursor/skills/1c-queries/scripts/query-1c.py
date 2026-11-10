#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Param:
    name: str
    value: Any


def _read_text_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def _parse_param(raw: str) -> Param:
    if "=" not in raw:
        raise ValueError(f"Bad --param format (expected Name=Value): {raw!r}")
    name, value = raw.split("=", 1)
    name = name.strip()
    value = value.strip()
    if not name:
        raise ValueError(f"Bad --param name: {raw!r}")

    # Try JSON first (numbers, booleans, null, arrays/objects, quoted strings)
    try:
        parsed = json.loads(value)
        return Param(name=name, value=parsed)
    except Exception:
        pass

    # Fallback: treat as plain string
    return Param(name=name, value=value)


def _normalize_query(query: str) -> str:
    # Keep original query readable but remove trailing whitespace noise.
    return "\n".join(line.rstrip() for line in query.strip().splitlines()).strip()


def _validate_query(query: str) -> list[str]:
    errors: list[str] = []
    q = query

    if re.search(r"&\w+", q):
        errors.append('Запрещены параметры вида "&ИмяПараметра". Подставляй значения явно или используй params_json.')

    if not re.search(r"\bВЫБРАТЬ\b", q, flags=re.IGNORECASE):
        errors.append("Не найдено ключевое слово ВЫБРАТЬ.")

    if not re.search(r"\bПЕРВЫЕ\s+\d+\b", q, flags=re.IGNORECASE):
        errors.append("Нет ограничения ПЕРВЫЕ N. Добавь ПЕРВЫЕ 10/50/100 и т.п.")

    return errors


def _params_json(params: list[Param]) -> str | None:
    if not params:
        return None
    payload = [{"name": p.name, "value": p.value} for p in params]
    return json.dumps(payload, ensure_ascii=False)


def _pretty_tsv(tsv: str, max_rows: int = 50) -> str:
    lines = [ln for ln in tsv.splitlines() if ln.strip() != ""]
    if not lines:
        return ""

    rows = [ln.split("\t") for ln in lines[: max_rows + 1]]
    headers = rows[0]
    data_rows = rows[1:]

    widths = [len(h) for h in headers]
    for r in data_rows[:max_rows]:
        for i in range(min(len(r), len(widths))):
            widths[i] = max(widths[i], len(r[i]))

    def fmt_row(r: list[str]) -> str:
        cells = []
        for i, w in enumerate(widths):
            v = r[i] if i < len(r) else ""
            cells.append(v.ljust(w))
        return " | ".join(cells).rstrip()

    out = []
    out.append(fmt_row(headers))
    out.append("-+-".join("-" * w for w in widths).rstrip())
    for r in data_rows[:max_rows]:
        out.append(fmt_row(r))
    if len(lines) - 1 > max_rows:
        out.append(f"... ({len(lines) - 1 - max_rows} строк(и) скрыто)")
    return "\n".join(out)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(
        description=(
            "Помощник для запросов 1С: валидирует текст, формирует params_json для MCP execute_1c_query, "
            "умеет красиво печатать TSV."
        )
    )
    src = p.add_mutually_exclusive_group(required=False)
    src.add_argument("--query", help="Текст запроса 1С")
    src.add_argument("--query-file", help="Путь к файлу с запросом (UTF-8)")
    p.add_argument(
        "--param",
        action="append",
        default=[],
        help='Параметр в формате Name=Value. Value можно задавать JSON (например 123, true, "строка", [1,2]).',
    )
    p.add_argument("--tsv", help="TSV результат (строкой). Если не указан, можно передать через stdin.")
    p.add_argument(
        "--tsv-stdin",
        action="store_true",
        help="Прочитать TSV из stdin (по умолчанию stdin не читается, чтобы не зависать в пайплайнах).",
    )
    p.add_argument("--max-rows", type=int, default=50, help="Максимум строк для pretty TSV")
    p.add_argument("--no-validate", action="store_true", help="Не валидировать запрос")

    args = p.parse_args(argv)

    query = ""
    if args.query_file:
        query = _read_text_file(args.query_file)
    elif args.query:
        query = args.query

    query = _normalize_query(query) if query else ""
    if query and not args.no_validate:
        errors = _validate_query(query)
        if errors:
            for e in errors:
                print(f"ERROR: {e}", file=sys.stderr)
            return 2

    params = [_parse_param(x) for x in args.param]
    params_json = _params_json(params)

    if query:
        # Print ready-to-use arguments for MCP execute_1c_query
        payload: dict[str, Any] = {"query": query}
        if params_json is not None:
            payload["params_json"] = params_json
        print(json.dumps(payload, ensure_ascii=False, indent=2))

    tsv = args.tsv
    if tsv is None and args.tsv_stdin:
        tsv = sys.stdin.read()

    if tsv:
        pretty = _pretty_tsv(tsv, max_rows=args.max_rows)
        if pretty:
            if query:
                print("\n--- TSV (pretty) ---\n")
            print(pretty)

    if not query and not tsv:
        p.print_help(sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
