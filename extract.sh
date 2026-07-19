#!/usr/bin/env bash
# read-paper extraction harness: dump a paper PDF to clean, analysis-ready text.
# This is the verified workhorse — poppler's `pdftotext` handles academic PDFs
# (LaTeX-derived text layers, two-column layouts, Unicode math) well enough that
# the agent can read equations straight from the text and re-render them as LaTeX.
#
# Usage:
#   extract.sh <paper.pdf>              # writes <paper>.txt beside the PDF
#   extract.sh <paper.pdf> <out.txt>    # writes to <out.txt>
#   extract.sh <paper.pdf> -            # writes to stdout
#
# Batch (one or more papers — loop from the shell):
#   for f in papers/*.pdf; do .claude/skills/read-paper/extract.sh "$f"; done
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <paper.pdf> [out.txt]" >&2
  exit 64
fi

PDF="$1"
OUT="${2:-${PDF%.pdf}.txt}"

if [ ! -f "$PDF" ]; then
  echo "ERROR: not a file: $PDF" >&2
  exit 66
fi

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "ERROR: pdftotext not found." >&2
  echo "  macOS:  brew install poppler" >&2
  echo "  Linux:  sudo apt-get install poppler-utils" >&2
  exit 127
fi

# Metadata (to stderr) so the agent sees what it's reading and how big.
echo "# $(basename "$PDF")" >&2
PAGES=$(pdfinfo "$PDF" 2>/dev/null | awk -F': *' '/^Pages:/ {print $2; exit}')
pdfinfo "$PDF" 2>/dev/null | grep -iE '^(Title|Author|Pages):' >&2 || true
echo "# --- extracted text below ---" >&2

if [ "$OUT" = "-" ]; then
  # stdout mode: stream text directly, no word-count available for the scan check.
  pdftotext -layout "$PDF" -
else
  pdftotext -layout "$PDF" "$OUT"
  WORDS=$(wc -w < "$OUT")
  echo "wrote $OUT ($(wc -l < "$OUT") lines, $WORDS words)" >&2
  # Heuristic scan detection: a normal letter/A4 text page carries hundreds of
  # words. Well under ~100 words/page ⇒ text layer is likely missing/garbage
  # (scanned image PDF). Don't fail — just tell the agent how to recover.
  if [ -n "$PAGES" ] && [ "$PAGES" -gt 2 ] 2>/dev/null; then
    WPP=$(( WORDS / PAGES ))
    if [ "$WPP" -lt 100 ]; then
      echo "# ⚠️  疑似扫描件/无可取文本层：$WORDS 词 / $PAGES 页 ≈ $WPP 词/页（阈值 100）。" >&2
      echo "#    pdftotext 对扫描图会吐乱码。请改用 Read 工具按页读 PDF 图片（Read(file_path=PDF, pages=\"1-5\")），" >&2
      echo "#    或先 ocrmypdf 处理后再抽取。本 skill 不内置 OCR。" >&2
    fi
  fi
fi
