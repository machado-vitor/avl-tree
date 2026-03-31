const std = @import("std");
const AvlTree = @import("avl_tree").AvlTree;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tree = AvlTree(i32, []const u8).init(allocator);
    defer tree.deinit();

    try tree.insert(42, "the answer");
    try tree.insert(7, "lucky");
    try tree.insert(13, "unlucky");
    try tree.insert(1, "first");
    try tree.insert(100, "century");

    var buf: [4096]u8 = undefined;
    var bw = std.fs.File.stdout().writer(&buf);
    const out = &bw.interface;

    try out.print("AVL tree: {d} nodes, height {d}\n", .{ tree.len, tree.treeHeight() });
    try out.print("min = {d}, max = {d}\n", .{ tree.min().?, tree.max().? });

    if (tree.search(42)) |val| {
        try out.print("search(42) = \"{s}\"\n", .{val});
    }

    _ = tree.delete(42);
    try out.print("after delete(42): {d} nodes, contains(42) = {}\n", .{ tree.len, tree.contains(42) });

    try out.flush();
}
