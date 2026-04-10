const std = @import("std");

pub const VisitorResult = enum { next, replace, stop };

pub fn Context(comptime State: type) type {
    return struct {
        state: *State,
    };
}

pub fn walk(
    comptime Node: type,
    comptime State: type,
    root: *Node,
    state: *State,
    visitors: anytype,
) anyerror!void {
    try doVisit(Node, State, visitors, root, state);
}

fn doVisit(
    comptime Node: type,
    comptime State: type,
    visitors: anytype,
    node: *Node,
    state: *State,
) anyerror!void {
    const tag = @tagName(node.kind);
    const ctx: Context(State) = .{ .state = state };

    const VisitorsType = @TypeOf(visitors);

    // Try exact kind tag match first (e.g. "element", "text")
    inline for (comptime std.meta.fieldNames(VisitorsType)) |name| {
        if (std.mem.eql(u8, name, tag)) {
            const result = try @field(visitors, name)(node, ctx);
            if (result != .stop) traverseChildren(Node, State, visitors, node, state);
            return;
        }
    }

    // Try language-specific type_name (e.g. "IfBlock", "SnippetBlock")
    if (node.type_name.len > 0) {
        inline for (comptime std.meta.fieldNames(VisitorsType)) |name| {
            if (std.mem.eql(u8, name, node.type_name)) {
                const result = try @field(visitors, name)(node, ctx);
                if (result != .stop) traverseChildren(Node, State, visitors, node, state);
                return;
            }
        }
    }

    // Fallback to default visitor "_"
    inline for (comptime std.meta.fieldNames(VisitorsType)) |name| {
        if (std.mem.eql(u8, name, "_")) {
            const result = try @field(visitors, name)(node, ctx);
            if (result != .stop) traverseChildren(Node, State, visitors, node, state);
            return;
        }
    }

    // No matching visitor — traverse children anyway
    traverseChildren(Node, State, visitors, node, state);
}

fn traverseChildren(
    comptime Node: type,
    comptime State: type,
    visitors: anytype,
    node: *Node,
    state: *State,
) void {
    for (node.children[0..node.children_len]) |child|
        doVisit(Node, State, visitors, child, state) catch return;
}
