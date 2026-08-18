#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

usage() {
  cat >&2 <<USAGE
Usage: $0 [build|clean]
  build (default): build markdown and html sources into docs/
  clean:          remove generated html files in docs/ and .build/
USAGE
  exit "${1:-64}"
}

action="${1:-build}"
case "$action" in
  build|clean) ;;
  -\?|--help) usage 0 ;;
  *) usage ;;
esac

clean() {
  rm -f docs/*.html
  rm -f .build/*.html
}

build() {
  typos src/*.md

  for md in src/*.md; do
    local name html
    name="$(basename "$md" .md)"
    html="$name.html"
    printf >&2 "building %s --> %s\n" "$md" ".build/$html"
    pandoc \
      --lua-filter="assets/meta-from-md.lua" \
      --metadata="mtime:$(git log -1 --format=%ct -- "$md" 2>/dev/null || date -r "$md" +%s)" \
      --template="assets/page.html" \
      --from=gfm+footnotes \
      "$md" -o ".build/$html"
    mv -v ".build/$html" "docs/$html"
  done

  # raw html files
  for html in src/*.html; do
    html="$(basename "$html")"
    cp "src/$html" "docs/$html"
  done

  # TODO remove html files that don't have corresponding sources
}

case "$action" in
  build) build ;;
  clean) clean ;;
esac
