# Zimmerframe

Generic AST walker for Zig — inspired by [zimmerframe](https://github.com/nicolo-ribaudo/zimmerframe).

## Usage

```zig
const walker = @import("walker");

// 1. Define your visitor functions
fn visitElement(node: *MyNode, ctx: walker.Context(State)) anyerror!walker.VisitorResult {
    // ... do something
    return .next;
}

// 2. Build visitor list
const visitors = [_]walker.VisitorEntry(MyNode, State){
    .{ .name = "element", .fn_ptr = visitElement },
    .{ .name = "_",       .fn_ptr = visitDefault },
};

// 3. Walk the tree
try walker.walk(MyNode, State, root, &state, &visitors);
```

## API

- `walk(Node, State, root, state, visitors)` — traverse AST, calling matching visitors
- `VisitorEntry(Node, State)` — struct `{ name, fn_ptr }`
- `Context(State)` — passed to each visitor, contains `state`
- `VisitorResult` — `.next`, `.replace`, `.stop`
