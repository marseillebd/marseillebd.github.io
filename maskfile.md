## find
> COmmand related to finding things on the local machine.

### find gitrepos [search_dir]

> Looks through the system for git repositories and reports information about them.

```bash
[ -n "$search_dir" ] || search_dir="$HOME"
find "$search_dir" -wholename '*/.git/config' | xargs dirname | xargs dirname
```
