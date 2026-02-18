# Assignment 1: Structs, Mappings, and Arrays (Solidity)

## 1) Structs
A `struct` is a custom data type that groups multiple fields together (like a record/object), for example:

```solidity
struct User {
    uint256 id;
    string name;
    bool active;
}
```

### Where structs are stored
- `storage`: persistent on-chain state (inside contract state variables).
- `memory`: temporary during a function call.
- `calldata`: read-only input data for external function parameters.

### Behavior when executed/called
- In `storage`, struct changes are permanent (cost gas).
- In `memory`, struct exists only during execution and is discarded after the call.
- Assigning `storage` struct to `memory` creates a copy.
- Using a `storage` reference updates original state directly.

## 2) Arrays
An array stores multiple values of the same type.

- Fixed-size: `uint[3]`
- Dynamic-size: `uint[]`

### Where arrays are stored
- `storage`: persistent contract state arrays.
- `memory`: temporary arrays created inside functions.
- `calldata`: read-only external input arrays.

### Behavior when executed/called
- `storage` arrays persist and can be modified (`push`, `pop` for dynamic arrays).
- `memory` arrays are temporary; size is fixed once created.
- Passing `storage` to `memory` copies data.
- Passing by `storage` reference lets you mutate original state.

## 3) Mappings
A mapping is a key-value lookup table:

```solidity
mapping(address => uint256) public balances;
```

### Where mappings are stored
- Mappings can exist only in `storage` as state (or as a storage reference).
- They are not iterable and do not store keys list automatically.
- Reading an unset key returns the type’s default value (for `uint`, that is `0`).

### Behavior when executed/called
- Writes update persistent contract state.
- Lookups are by key and efficient.
- No length and no built-in way to enumerate all keys.

## 4) Why you don’t specify `memory`/`storage` for mappings (the logic)
You usually do not write `memory` for mappings because **mappings are not supported in memory** in normal Solidity usage. They are designed for state storage hashing layout, not temporary linear memory layout.

So:
- A state mapping is already in `storage`.
- If used inside functions, it is typically via a `storage` reference.
- `calldata` mapping parameters are also not used in standard function signatures.

That is why mappings feel “special”: Solidity restricts them to `storage`-style usage, so you normally do not choose between `memory` and `storage` the same way you do for structs/arrays.
