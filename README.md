# avl-tree

An AVL tree in Zig. Generic over key and value types.

## Usage

```zig
const std = @import("std");
const AvlTree = @import("avl_tree").AvlTree;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var tree = AvlTree(i32, []const u8).init(gpa.allocator());
    defer tree.deinit();

    try tree.insert(1, "one");
    try tree.insert(2, "two");
    try tree.insert(3, "three");

    std.debug.print("{s}\n", .{tree.search(2).?});

    tree.delete(2);
}
```

The key type needs to support `<` and `>`.

## API

- `init(allocator)` / `deinit()`
- `insert(key, value)` — inserts or updates if the key already exists
- `search(key)` — returns `?V`
- `delete(key)` — no-op if the key isn't there

## Build

```
zig build test
```
