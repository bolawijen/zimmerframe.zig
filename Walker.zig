const std = @import("std");

pub const VisitorResult = enum { next, replace, stop };

pub fn Context(comptime State: type) type {
    return struct {
        state: *State,
    };
}

/// Default behavior: Smart detection untuk pola .type
pub fn defaultGenerator(node: anytype) struct { tag: []const u8 } {
    const T = @TypeOf(node.*);
    
    if (comptime !@hasField(T, "type")) {
        @compileError("Default walker requires a '.type' field in your Node struct. " ++
                     "If your AST uses a different pattern, use 'walkWithGenerator'.");
    }
    
    return .{ .tag = @tagName(node.type) };
}

/// Main walk function with type inference
pub fn walk(
    root: anytype,
    state: anytype,
    visitors: anytype,
) anyerror!void {
    const Node = @TypeOf(root.*);
    const State = @TypeOf(state.*);
    try doVisit(Node, State, visitors, root, state, defaultGenerator);
}

/// Walk with custom generator and type inference
pub fn walkWithGenerator(
    root: anytype,
    state: anytype,
    visitors: anytype,
    comptime generator: anytype,
) anyerror!void {
    const Node = @TypeOf(root.*);
    const State = @TypeOf(state.*);
    try doVisit(Node, State, visitors, root, state, generator);
}

fn doVisit(
    comptime T: type,
    comptime State: type,
    visitors: anytype,
    node: *T,
    state: *State,
    comptime generator: anytype,
) anyerror!void {
    const entry = generator(node);
    
    const node_info = @typeInfo(T);
    if (node_info == .@"union") {
        const tag = std.meta.activeTag(node.*);
        const tag_name = @tagName(tag);
        inline for (node_info.@"union".fields) |field| {
            if (std.mem.eql(u8, field.name, tag_name)) {
                const inner_node = &@field(node.*, field.name);
                try dispatch(field.type, State, visitors, inner_node, entry.tag, state, generator);
                return;
            }
        }
    } else {
        try dispatch(T, State, visitors, node, entry.tag, state, generator);
    }
}

fn dispatch(
    comptime T: type,
    comptime State: type,
    visitors: anytype,
    node: *T,
    tag: []const u8,
    state: *State,
    comptime generator: anytype,
) anyerror!void {
    const VisitorsType = comptime blk: {
        const V = @TypeOf(visitors);
        break :blk if (V == type) visitors else V;
    };
    
    var visited = false;
    const info = @typeInfo(VisitorsType);
    if (info == .@"struct") {
        inline for (info.@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, tag)) {
                const result = try @field(visitors, field.name)(node, state);
                if (result != .stop) try traverseChildren(State, visitors, T, node, state, generator);
                visited = true;
                break;
            }
        }

        if (!visited) {
            inline for (info.@"struct".decls) |decl| {
                if (std.mem.eql(u8, decl.name, tag)) {
                    const DeclType = @TypeOf(@field(VisitorsType, decl.name));
                    if (@typeInfo(DeclType) == .@"fn") {
                        const result = try @field(VisitorsType, decl.name)(node, state);
                        if (result != .stop) try traverseChildren(State, visitors, T, node, state, generator);
                        visited = true;
                        break;
                    }
                }
            }
        }
    }

    if (!visited) {
        const has_default = comptime @hasDecl(VisitorsType, "_") or @hasField(VisitorsType, "_");
        if (has_default) {
            if (comptime @hasDecl(VisitorsType, "_")) {
                 const result = try @field(VisitorsType, "_")(node, state);
                 if (result != .stop) try traverseChildren(State, visitors, T, node, state, generator);
            } else {
                 const result = try @field(visitors, "_")(node, state);
                 if (result != .stop) try traverseChildren(State, visitors, T, node, state, generator);
            }
        } else {
            try traverseChildren(State, visitors, T, node, state, generator);
        }
    }
}

fn traverseChildren(
    comptime State: type,
    visitors: anytype,
    comptime T: type,
    node: *T,
    state: *State,
    comptime generator: anytype,
) anyerror!void {
    const info = @typeInfo(T);
    if (info != .@"struct") return;

    inline for (info.@"struct".fields) |field| {
        if (comptime std.mem.eql(u8, field.name, "props")) continue;
        const field_value = &@field(node.*, field.name);
        try walkAny(State, visitors, field.type, field_value, state, generator);
    }
}

fn walkAny(
    comptime State: type,
    visitors: anytype,
    comptime T: type,
    value_ptr: anytype,
    state: *State,
    comptime generator: anytype,
) anyerror!void {
    const info = @typeInfo(T);
    switch (info) {
        .pointer => |ptr| {
            if (ptr.size == .slice) {
                for (value_ptr.*) |*item| {
                    try walkAny(State, visitors, ptr.child, item, state, generator);
                }
            } else {
                try visitIfNode(State, visitors, ptr.child, value_ptr.*, state, generator);
            }
        },
        .optional => |opt| {
            if (value_ptr.*) |*unwrapped| {
                try walkAny(State, visitors, opt.child, unwrapped, state, generator);
            }
        },
        .@"struct", .@"union" => {
            try visitIfNode(State, visitors, T, value_ptr, state, generator);
        },
        else => {},
    }
}

fn visitIfNode(
    comptime State: type,
    visitors: anytype,
    comptime T: type,
    node_ptr: anytype,
    state: *State,
    comptime generator: anytype,
) anyerror!void {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct", .@"union" => {
            if (comptime @hasField(T, "items") and (@hasField(T, "capacity") or @hasField(T, "cap"))) {
                for (node_ptr.items) |child| {
                    try visitIfNode(State, visitors, @TypeOf(child.*), child, state, generator);
                }
            } else {
                try doVisit(T, State, visitors, node_ptr, state, generator);
            }
        },
        else => {},
    }
}
