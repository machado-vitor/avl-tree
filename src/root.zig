const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// A self-balancing AVL binary search tree, generic over key type K and value type V.
/// K must support `<` and `>` operators (integer and float types).
pub fn AvlTree(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            key: K,
            value: V,
            left: ?*Node = null,
            right: ?*Node = null,
            height: i32 = 1,
        };

        root: ?*Node = null,
        allocator: Allocator,
        len: usize = 0,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            freeSubtree(self.allocator, self.root);
            self.root = null;
            self.len = 0;
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
            return nodeHeight(node.left) - nodeHeight(node.right);
        }

        fn updateHeight(node: *Node) void {
            node.height = 1 + @max(nodeHeight(node.left), nodeHeight(node.right));
        }

        // Single right rotation (fixes left-left imbalance).
        //
        //       y              x
        //      / \            / \
        //     x   T3  →     T1   y
        //    / \                 / \
        //   T1  T2             T2  T3
        //
        fn rotateRight(y: *Node) *Node {
            const x = y.left.?;
            y.left = x.right;
            x.right = y;
            updateHeight(y);
            updateHeight(x);
            return x;
        }

        // Single left rotation (fixes right-right imbalance).
        //
        //     x                y
        //    / \              / \
        //   T1   y    →     x   T3
        //       / \        / \
        //      T2  T3    T1  T2
        //
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

            // Left-heavy (bf > 1)
            if (bf > 1) {
                if (balanceFactor(node.left.?) < 0) {
                    // Left-Right case: left-rotate the left child first
                    node.left = rotateLeft(node.left.?);
                }
                return rotateRight(node);
            }

            // Right-heavy (bf < -1)
            if (bf < -1) {
                if (balanceFactor(node.right.?) > 0) {
                    // Right-Left case: right-rotate the right child first
                    node.right = rotateRight(node.right.?);
                }
                return rotateLeft(node);
            }

            return node;
        }

        /// Insert a key-value pair. If the key already exists, the value is updated.
        pub fn insert(self: *Self, key: K, value: V) Allocator.Error!void {
            var inserted = false;
            self.root = try insertAt(self.allocator, self.root, key, value, &inserted);
            if (inserted) self.len += 1;
        }

        fn insertAt(allocator: Allocator, node: ?*Node, key: K, value: V, inserted: *bool) Allocator.Error!*Node {
            const n = node orelse {
                const new = try allocator.create(Node);
                new.* = .{ .key = key, .value = value };
                inserted.* = true;
                return new;
            };

            if (key < n.key) {
                n.left = try insertAt(allocator, n.left, key, value, inserted);
            } else if (key > n.key) {
                n.right = try insertAt(allocator, n.right, key, value, inserted);
            } else {
                n.value = value;
            }

            return rebalance(n);
        }

        /// Look up a value by key. Returns null if the key is not in the tree.
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

        /// Returns true if the key exists in the tree.
        pub fn contains(self: *const Self, key: K) bool {
            return self.search(key) != null;
        }

        /// Remove a key from the tree. Returns true if the key was found and removed.
        pub fn delete(self: *Self, key: K) bool {
            var deleted = false;
            self.root = deleteAt(self.allocator, self.root, key, &deleted);
            if (deleted) self.len -= 1;
            return deleted;
        }

        fn deleteAt(allocator: Allocator, node: ?*Node, key: K, deleted: *bool) ?*Node {
            const n = node orelse return null;

            if (key < n.key) {
                n.left = deleteAt(allocator, n.left, key, deleted);
            } else if (key > n.key) {
                n.right = deleteAt(allocator, n.right, key, deleted);
            } else {
                deleted.* = true;

                // Leaf or single-child: splice out
                if (n.left == null or n.right == null) {
                    const child = n.left orelse n.right;
                    allocator.destroy(n);
                    return child;
                }

                // Two children: replace with in-order successor (min of right subtree),
                // then delete the successor from the right subtree.
                const successor = minNode(n.right.?);
                n.key = successor.key;
                n.value = successor.value;
                var dummy = false;
                n.right = deleteAt(allocator, n.right, successor.key, &dummy);
            }

            return rebalance(n);
        }

        fn minNode(node: *Node) *Node {
            var current = node;
            while (current.left) |left| {
                current = left;
            }
            return current;
        }

        /// Returns the smallest key, or null if the tree is empty.
        pub fn min(self: *const Self) ?K {
            const r = self.root orelse return null;
            return minNode(r).key;
        }

        /// Returns the largest key, or null if the tree is empty.
        pub fn max(self: *const Self) ?K {
            var current = self.root orelse return null;
            while (current.right) |right| {
                current = right;
            }
            return current.key;
        }

        /// Returns the height of the tree (0 for empty).
        pub fn treeHeight(self: *const Self) i32 {
            return nodeHeight(self.root);
        }

        /// Collect all keys in sorted (in-order) order. Caller owns the returned slice.
        pub fn inOrderKeys(self: *const Self, allocator: Allocator) Allocator.Error![]K {
            var list: std.ArrayList(K) = .empty;
            errdefer list.deinit(allocator);
            try collectInOrder(self.root, &list, allocator);
            return list.toOwnedSlice(allocator);
        }

        fn collectInOrder(node: ?*Node, list: *std.ArrayList(K), allocator: Allocator) Allocator.Error!void {
            const n = node orelse return;
            try collectInOrder(n.left, list, allocator);
            try list.append(allocator, n.key);
            try collectInOrder(n.right, list, allocator);
        }

        /// Verify BST ordering, AVL balance, and stored heights (testing only).
        fn verify(node: ?*Node) !void {
            const n = node orelse return;
            try verify(n.left);
            try verify(n.right);

            // Height must equal 1 + max(left height, right height)
            const expected_h = 1 + @max(nodeHeight(n.left), nodeHeight(n.right));
            try testing.expectEqual(expected_h, n.height);

            // Balance factor must be in {-1, 0, 1}
            const bf = balanceFactor(n);
            try testing.expect(bf >= -1 and bf <= 1);

            // BST ordering
            if (n.left) |left| try testing.expect(left.key < n.key);
            if (n.right) |right| try testing.expect(right.key > n.key);
        }
    };
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════════

const IntTree = AvlTree(i32, i32);

test "empty tree" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try testing.expectEqual(0, tree.len);
    try testing.expect(tree.search(1) == null);
    try testing.expect(!tree.contains(1));
    try testing.expect(tree.min() == null);
    try testing.expect(tree.max() == null);
    try testing.expect(!tree.delete(1));
}

test "single insert and search" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(10, 100);

    try testing.expectEqual(1, tree.len);
    try testing.expectEqual(100, tree.search(10).?);
    try testing.expect(tree.contains(10));
    try testing.expect(!tree.contains(20));
}

test "duplicate key updates value" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(10, 100);
    try tree.insert(10, 200);

    try testing.expectEqual(1, tree.len);
    try testing.expectEqual(200, tree.search(10).?);
}

test "left rotation — right-right case" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    // 10 → 20 → 30 triggers left rotation; 20 becomes root
    try tree.insert(10, 0);
    try tree.insert(20, 0);
    try tree.insert(30, 0);

    try IntTree.verify(tree.root);
    try testing.expectEqual(20, tree.root.?.key);
    try testing.expectEqual(10, tree.root.?.left.?.key);
    try testing.expectEqual(30, tree.root.?.right.?.key);
}

test "right rotation — left-left case" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    // 30 → 20 → 10 triggers right rotation; 20 becomes root
    try tree.insert(30, 0);
    try tree.insert(20, 0);
    try tree.insert(10, 0);

    try IntTree.verify(tree.root);
    try testing.expectEqual(20, tree.root.?.key);
    try testing.expectEqual(10, tree.root.?.left.?.key);
    try testing.expectEqual(30, tree.root.?.right.?.key);
}

test "left-right double rotation" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(30, 0);
    try tree.insert(10, 0);
    try tree.insert(20, 0);

    try IntTree.verify(tree.root);
    try testing.expectEqual(20, tree.root.?.key);
}

test "right-left double rotation" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(10, 0);
    try tree.insert(30, 0);
    try tree.insert(20, 0);

    try IntTree.verify(tree.root);
    try testing.expectEqual(20, tree.root.?.key);
}

test "multiple inserts preserve AVL invariants" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    const keys = [_]i32{ 10, 20, 30, 40, 50, 25 };
    for (keys) |k| {
        try tree.insert(k, k * 10);
    }

    try testing.expectEqual(6, tree.len);
    for (keys) |k| {
        try testing.expectEqual(k * 10, tree.search(k).?);
    }
    try IntTree.verify(tree.root);
}

test "delete leaf node" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(20, 0);
    try tree.insert(10, 0);
    try tree.insert(30, 0);

    try testing.expect(tree.delete(10));
    try testing.expectEqual(2, tree.len);
    try testing.expect(!tree.contains(10));
    try IntTree.verify(tree.root);
}

test "delete node with one child" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(20, 0);
    try tree.insert(10, 0);
    try tree.insert(30, 0);
    try tree.insert(25, 0);

    try testing.expect(tree.delete(30));
    try testing.expect(!tree.contains(30));
    try testing.expect(tree.contains(25));
    try IntTree.verify(tree.root);
}

test "delete node with two children" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(20, 0);
    try tree.insert(10, 0);
    try tree.insert(30, 0);
    try tree.insert(25, 0);
    try tree.insert(35, 0);

    try testing.expect(tree.delete(30));
    try testing.expect(!tree.contains(30));
    try testing.expect(tree.contains(25));
    try testing.expect(tree.contains(35));
    try IntTree.verify(tree.root);
}

test "delete nonexistent key returns false" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(10, 10);

    try testing.expect(!tree.delete(99));
    try testing.expectEqual(1, tree.len);
}

test "delete root of single-node tree" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try tree.insert(10, 10);
    try testing.expect(tree.delete(10));
    try testing.expectEqual(0, tree.len);
    try testing.expect(tree.root == null);
}

test "delete triggers rebalance" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    //       20
    //      /  \
    //    10    30
    //   /        \
    //  5          35
    try tree.insert(20, 0);
    try tree.insert(10, 0);
    try tree.insert(30, 0);
    try tree.insert(5, 0);
    try tree.insert(35, 0);

    // Deleting 10 makes left subtree shorter; deleting 5 next would leave
    // the left side empty, triggering a rotation.
    try testing.expect(tree.delete(10));
    try testing.expect(tree.delete(5));
    try IntTree.verify(tree.root);
    try testing.expectEqual(3, tree.len);
}

test "min and max" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    const keys = [_]i32{ 20, 10, 30, 5, 25 };
    for (keys) |k| {
        try tree.insert(k, 0);
    }

    try testing.expectEqual(5, tree.min().?);
    try testing.expectEqual(30, tree.max().?);
}

test "in-order traversal returns sorted keys" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    const keys = [_]i32{ 50, 30, 70, 20, 40, 60, 80 };
    for (keys) |k| {
        try tree.insert(k, 0);
    }

    const sorted = try tree.inOrderKeys(testing.allocator);
    defer testing.allocator.free(sorted);

    try testing.expectEqualSlices(i32, &[_]i32{ 20, 30, 40, 50, 60, 70, 80 }, sorted);
}

test "100 sequential ascending insertions stay balanced" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    for (1..101) |i| {
        try tree.insert(@intCast(i), @intCast(i));
    }

    try testing.expectEqual(100, tree.len);
    try IntTree.verify(tree.root);
    // AVL height for n nodes is at most ~1.44·log₂(n+2). For 100: ≤ 10.
    try testing.expect(tree.treeHeight() <= 10);
}

test "100 sequential descending insertions stay balanced" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    var i: i32 = 100;
    while (i >= 1) : (i -= 1) {
        try tree.insert(i, i);
    }

    try testing.expectEqual(100, tree.len);
    try IntTree.verify(tree.root);
    try testing.expect(tree.treeHeight() <= 10);
}

test "delete all nodes one by one" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    for (1..21) |i| {
        try tree.insert(@intCast(i), 0);
    }

    for (1..21) |i| {
        try testing.expect(tree.delete(@intCast(i)));
        if (tree.root != null) try IntTree.verify(tree.root);
    }

    try testing.expectEqual(0, tree.len);
    try testing.expect(tree.root == null);
}

test "interleaved insert and delete maintains invariants" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    const initial = [_]i32{ 5, 3, 8, 1, 4, 7, 9, 2, 6 };
    for (initial) |k| {
        try tree.insert(k, k * 10);
    }
    try IntTree.verify(tree.root);

    // Delete interior nodes
    try testing.expect(tree.delete(5));
    try IntTree.verify(tree.root);
    try testing.expect(tree.delete(3));
    try IntTree.verify(tree.root);

    // Insert new nodes
    try tree.insert(10, 100);
    try tree.insert(11, 110);
    try IntTree.verify(tree.root);

    // Delete another interior node
    try testing.expect(tree.delete(8));
    try IntTree.verify(tree.root);

    try testing.expectEqual(8, tree.len);
    try testing.expect(!tree.contains(5));
    try testing.expect(!tree.contains(3));
    try testing.expect(!tree.contains(8));
    try testing.expect(tree.contains(10));
    try testing.expectEqual(60, tree.search(6).?);
}

test "height tracks insertions and deletions" {
    var tree = IntTree.init(testing.allocator);
    defer tree.deinit();

    try testing.expectEqual(0, tree.treeHeight());

    try tree.insert(1, 0);
    try testing.expectEqual(1, tree.treeHeight());

    try tree.insert(2, 0);
    try testing.expectEqual(2, tree.treeHeight());

    try tree.insert(3, 0); // triggers rotation → height stays 2
    try testing.expectEqual(2, tree.treeHeight());

    _ = tree.delete(1);
    _ = tree.delete(2);
    _ = tree.delete(3);
    try testing.expectEqual(0, tree.treeHeight());
}
