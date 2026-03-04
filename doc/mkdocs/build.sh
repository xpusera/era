#!/bin/sh -e

# Split lua_api.md on top level headings
rm -f docs/section*
cat ../lua_api.md | csplit -sz -f docs/section - '/^=/-1' '{*}'

cat > mkdocs.yml << EOF
site_name: Minetek Documentation
theme:
  name: material
  palette:
    - scheme: slate
      primary: black
      accent: light blue
  features:
    - navigation.sections
    - navigation.top
extra_css:
  - css/code_styles.css
  - css/extra.css
markdown_extensions:
  - toc:
      permalink: True
  - pymdownx.superfences
  - pymdownx.highlight:
      css_class: codehilite
  - gfm_admonition
plugins:
  - search:
      separator: '[\s\-\.\(]+'
nav:
  - "Home": index.md
  - "Fork APIs": fork-apis.md
  - "Menu Lua API": menu-lua-api.md
  - "Client Lua API": client-lua-api.md
EOF

mv docs/section00 docs/index.md

cp -f ../../APIS.md docs/fork-apis.md
cp -f ../menu_lua_api.md docs/menu-lua-api.md
cp -f ../client_lua_api.md docs/client-lua-api.md

for f in docs/section*
do
	title=$(head -1 $f)
	fname=$(echo $title | tr '[:upper:]' '[:lower:]')
	fname=$(echo $fname | sed 's/ /-/g')
	fname=$(echo $fname | sed "s/'//g").md
	mv $f docs/$fname
	echo "  - \"$title\": $fname" >> mkdocs.yml
done

mkdocs build --site-dir ../../public
