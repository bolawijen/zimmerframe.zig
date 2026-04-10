const std = @import("std");

pub const VisitorResult = enum { next, replace, stop };

pub fn Context(comptime State: type) type {
    return struct {
        state: *State,
    };
}

pub fn VisitorFn(comptime Node: type, comptime State: type) type {
    return *const fn (*Node, Context(State)) anyerror!VisitorResult;
}

pub fn VisitorEntry(comptime Node: type, comptime State: type) type {
    return struct {
        name: []const u8,
        fn_ptr: VisitorFn(Node, State),
    };
}

pub fn walk(
    comptime Node: type,
    comptime State: type,
    root: *Node,
    state: *State,
    visitors: []const VisitorEntry(Node, State),
) anyerror!void {
    try doVisit(Node, State, visitors, root, state);
}

fn doVisit(
    comptime Node: type,
    comptime State: type,
    visitors: []const VisitorEntry(Node, State),
    node: *Node,
    state: *State,
) anyerror!void {
    const tag = @tagName(node.kind);
    const ctx: Context(State) = .{ .state = state };

    const fn_ptr = findVisitor(Node, State, visitors, tag, node.type_name);

    if (fn_ptr) |call_fn| {
        const result = try call_fn(node, ctx);
        if (result != .stop)
            traverseChildren(Node, State, visitors, node, state);
        return;
    }

    traverseChildren(Node, State, visitors, node, state);
}

fn findVisitor(
    comptime Node: type,
    comptime State: type,
    visitors: []const VisitorEntry(Node, State),
    tag: []const u8,
    type_name: []const u8,
) ?VisitorFn(Node, State) {
    for (visitors) |v|
        if (std.mem.eql(u8, v.name, tag) or std.mem.eql(u8, v.name, type_name))
            return v.fn_ptr;

    for (visitors) |v|
        if (std.mem.eql(u8, v.name, "_"))
            return v.fn_ptr;

    return null;
}

fn traverseChildren(
    comptime Node: type,
    comptime State: type,
    visitors: []const VisitorEntry(Node, State),
    node: *Node,
    state: *State,
) void {
    for (node.children[0..node.children_len]) |child|
        doVisit(Node, State, visitors, child, state) catch return;
}
