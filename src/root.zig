const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub fn AvlTree(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            key: K,
            value: V,
            left: ?*Node = null,
            right: ?*Node = null,
            height: i32 = 1, // leaves start at 1; null children count as 0
        };

        root: ?*Node = null,
        allocator: Allocator,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            freeSubtree(self.allocator, self.root);
            self.root = null;
        }

        fn freeSubtree(allocator: Allocator, node: ?*Node) void {
            const n = node orelse return;
            freeSubtree(allocator, n.left);
            freeSubtree(allocator, n.right);
            allocator.destroy(n);
        }

        fn nodeHeight(node: ?*Node) i32 {
            return if (node) |n| n.height else 0;
        }

        fn balanceFactor(node: *Node) i32 {
            // > 0 means left-heavy, < 0 means right-heavy. AVL invariant: |bf| <= 1
            return nodeHeight(node.left) - nodeHeight(node.right);
        }

        fn updateHeight(node: *Node) void {
            node.height = 1 + @max(nodeHeight(node.left), nodeHeight(node.right));
        }

        // fixes left-heavy: x bubbles up, y becomes x's right child
        fn rotateRight(y: *Node) *Node {
            const x = y.left.?;
            y.left = x.right;
            x.right = y;
            updateHeight(y); // update y first — it's now lower in the tree
            updateHeight(x);
            return x;
        }

        // mirror of rotateRight: fixes right-heavy
        fn rotateLeft(x: *Node) *Node {
            const y = x.right.?;
            x.right = y.left;
            y.left = x;
            updateHeight(x);
            updateHeight(y);
            return y;
        }

        fn rebalance(node: *Node) *Node {
            updateHeight(node);
            const bf = balanceFactor(node);
            if (bf > 1) {
                // left-heavy. if left child leans right, it's the left-right case — pre-rotate left
                if (balanceFactor(node.left.?) < 0) node.left = rotateLeft(node.left.?);
                return rotateRight(node);
            }
            if (bf < -1) {
                // mirror: right-left case needs a right rotation on the right child first
                if (balanceFactor(node.right.?) > 0) node.right = rotateRight(node.right.?);
                return rotateLeft(node);
            }
            return node;
        }

        pub fn insert(self: *Self, key: K, value: V) Allocator.Error!void {
            self.root = try insertAt(self.allocator, self.root, key, value);
        }

        fn insertAt(allocator: Allocator, node: ?*Node, key: K, value: V) Allocator.Error!*Node {
            const n = node orelse {
                const new = try allocator.create(Node);
                new.* = .{ .key = key, .value = value };
                return new;
            };
            if (key < n.key) {
                n.left = try insertAt(allocator, n.left, key, value);
            } else if (key > n.key) {
                n.right = try insertAt(allocator, n.right, key, value);
            } else {
                n.value = value; // duplicate key — overwrite
            }
            // rebalance on the way back up; one rotation per level is enough
            return rebalance(n);
        }

        pub fn search(self: *const Self, key: K) ?V {
            var current = self.root;
            while (current) |n| {
                if (key < n.key) {
                    current = n.left;
                } else if (key > n.key) {
                    current = n.right;
                } else {
                    return n.value;
                }
            }
            return null;
        }

        pub fn delete(self: *Self, key: K) void {
            self.root = deleteAt(self.allocator, self.root, key);
        }

        fn deleteAt(allocator: Allocator, node: ?*Node, key: K) ?*Node {
            const n = node orelse return null; // key not in tree — no-op
            if (key < n.key) {
                n.left = deleteAt(allocator, n.left, key);
            } else if (key > n.key) {
                n.right = deleteAt(allocator, n.right, key);
            } else {
                // 0 or 1 child: splice the child in place of n
                if (n.left == null or n.right == null) {
                    const child = n.left orelse n.right;
                    allocator.destroy(n);
                    return child;
                }
                // 2 children: copy inorder successor into n, then delete it from the right subtree
                const successor = minNode(n.right.?);
                n.key = successor.key;
                n.value = successor.value;
                n.right = deleteAt(allocator, n.right, successor.key);
            }
            return rebalance(n);
        }

        fn minNode(node: *Node) *Node {
            var current = node;
            while (current.left) |left| current = left;
            return current;
        }

        fn verify(node: ?*Node) !void {
            const n = node orelse return;
            try verify(n.left);
            try verify(n.right);
            try testing.expectEqual(1 + @max(nodeHeight(n.left), nodeHeight(n.right)), n.height);
            const bf = balanceFactor(n);
            try testing.expect(bf >= -1 and bf <= 1);
            if (n.left) |left| try testing.expect(left.key < n.key);
            if (n.right) |right| try testing.expect(right.key > n.key);
        }
    };
}

const IntTree = AvlTree(i32, i32);

test "insert and search" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();
    try tree.insert(10, 100);
    try testing.expectEqual(100, tree.search(10).?);
    try testing.expect(tree.search(20) == null);
}

test "duplicate key updates value" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();
    try tree.insert(10, 100);
    try tree.insert(10, 200);
    try testing.expectEqual(200, tree.search(10).?);
}

test "all four rotations balance to 20 as root" {
    const cases = [_][3]i32{
        .{ 10, 20, 30 }, // right-right → left rotation
        .{ 30, 20, 10 }, // left-left   → right rotation
        .{ 30, 10, 20 }, // left-right
        .{ 10, 30, 20 }, // right-left
    };
    for (cases) |keys| {
        var tree = IntTree.init(testing.allocator);
        defer tree.deinit();
        for (keys) |k| try tree.insert(k, 0);
        try IntTree.verify(tree.root);
        try testing.expectEqual(20, tree.root.?.key);
    }
}

test "delete leaf, one-child, and two-child nodes" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();
    for ([_]i32{ 20, 10, 30, 25, 35 }) |k| try tree.insert(k, k);

    tree.delete(10); // leaf
    tree.delete(35); // leaf
    tree.delete(30); // had two children before previous delete; now one child (25)
    tree.delete(999); // nonexistent — no-op

    try IntTree.verify(tree.root);
    try testing.expect(tree.search(10) == null);
    try testing.expectEqual(20, tree.search(20).?);
    try testing.expectEqual(25, tree.search(25).?);
}

test "100 ascending inserts stay balanced" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();
    for (1..101) |i| try tree.insert(@intCast(i), 0);
    try IntTree.verify(tree.root);
    try testing.expect(IntTree.nodeHeight(tree.root) <= 10);
}
