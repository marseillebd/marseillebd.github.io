# https://just.systems


default: build

build:
  #!/usr/bin/env bash
  set -euo pipefail
  typos src/*.md
  for md in src/*.md; do
    html="$(basename "${md%.md}.html")"
    # TODO skip building html that is newer than the corresponding md
    printf >&2 "building %s --> %s\n" "$md" "build/$html"
    pandoc \
      --lua-filter="assets/meta-from-md.lua" \
      --template="assets/page.html" \
      --from=gfm+footnotes \
      "$md" -o "build/$html"
    printf >&2 "OK %s --> %s\n" "build/$html" "docs/$html"
    mv "build/$html" "docs/$html"
  done
  # TODO remove html files that don't have corresponding md

clean:
  rm -f docs/*.html
  rm -f build/*.html
