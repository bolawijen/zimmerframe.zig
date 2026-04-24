# Walker

A universal AST walker for Zig, inspired by [zimmerframe](https://github.com/Rich-Harris/zimmerframe). Designed to work with any data structure with minimal configuration and clean separation of concerns.

## Key Features

- **Blind Traversal**: Automatically traverses ALL struct fields (pointers, slices, optionals) to find child nodes.
- **Smart Discovery**: Default generator automatically recognizes the `.type` pattern (Estree style).
- **Type Inference**: No need to pass Node or State types explicitly.
- **Parallel Safe**: Supports multi-threaded AST processing using independent State instances.
- **Clean Separation**: Separation between traversal logic (Walker), data container (State), and transformation logic (Visitors).

## Standard Usage

```zig
try walker.walk(
    &root_node,     // Root of traversal
    &state,         // Data instance (State)
    Visitors        // Module containing visitor functions
);
```

## Custom Generators

If your AST uses a unique schema, you can provide a custom generator:

```zig
fn myGenerator(node: anytype) struct { tag: []const u8 } {
    return .{ .tag = @tagName(node.custom_type_field) };
}

try walker.walkWithGenerator(root, state, Visitors, myGenerator);
```

## Visitor API

Visitors are defined as top-level functions receiving the node and state:

```zig
pub fn element(node: *Node, state: *State) anyerror!walker.VisitorResult {
    // Your logic here
    return .next;
}
```
