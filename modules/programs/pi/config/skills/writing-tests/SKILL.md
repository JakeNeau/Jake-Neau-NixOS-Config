---
name: writing-tests
description: Use before writing or changing any test. The house style for tests: arrange/act/assert, behaviour over implementation, no logic in tests, DAMP over DRY, fakes over mocks, property-based tests and file snapshots where they fit.
---

# Writing tests

A test documents one behaviour and fails only when that behaviour breaks. The
rules below keep tests readable on their own and stable across refactors; each
gives its reason so you can apply it to cases the examples don't show.

## Structure

### Arrange, act, assert
Every test has the three phases in that order, visibly separated. Why: a
reader finds the setup, the one call under test, and the expectation without
hunting.

```ts
test("a frozen account rejects withdrawals", () => {
  const account = frozenAccount({ balance: 100 });   // arrange

  const result = account.withdraw(10);               // act

  expect(result).toEqual(rejected("frozen"));        // assert
});
```

Use the project's own convention for the phases (Given/When/Then is the same
shape).

### One behaviour per test
The name states the behaviour in plain words; the body proves exactly that.
Why: a failing test should name what broke without reading the body.

## What to test

### Behaviour, not implementation
Assert on what a caller can observe: return values, state through the public
interface, emitted events. Why: a test tied to private structure fails on
every refactor and passes on real bugs.

```python
# implementation: breaks when the cache changes shape
assert service._cache["user:1"] is not None

# behaviour: survives any cache
assert service.user(1) == service.user(1)
assert fake_db.reads == 1
```

### Fakes over mocks
Prefer a small working implementation (an in-memory store, a fixed clock)
over a mock that records calls. Why: a fake tests the behaviour; a mock tests
that you called what you expected to call, which is implementation.

```ts
const db = new InMemoryUserDb([alice]);      // fake
const users = new UserService(db);
expect(users.find("alice")).toEqual(alice);
```

### Property-based tests
Where a property holds for all inputs, state it and let the framework
generate the inputs. Why: a property catches the case you did not think to
write.

```rust
proptest! {
    fn roundtrip(cfg in any::<Config>()) {
        prop_assert_eq!(parse(&render(&cfg))?, cfg);
    }
}
```

### File snapshots
For large outputs (rendered templates, generated code, serialized trees),
compare against a committed snapshot file. Why: an inline expectation of
hundreds of lines is unreadable and unreviewable; a snapshot diff is both.

## Style

### No logic in tests
Tests hold no branches, loops, or computed expectations. Why: logic in a test
needs its own test; a literal expectation cannot be wrong in a hidden way.

```ts
// computed: hides what the answer should be
expect(total(items)).toBe(items.reduce((s, i) => s + i.price, 0));

// literal
expect(total([book, pen])).toBe(1250);
```

### DAMP over DRY
Repeat setup for clarity rather than factoring it into shared helpers. Why: a
test should read top to bottom without jumping to a fixture; duplication in
tests is cheap and coupling is not. A named builder for one object
(`frozenAccount(...)`) is fine; a shared `beforeEach` that half the tests
depend on is not.

## Decision points

- Fake versus real: use the real dependency when it is fast and
  deterministic; a fake when it is not.
- Property versus example: keep at least one example test beside a property,
  so a failure has a concrete case to read.
- Snapshot versus assertion: a snapshot for output a human would review as a
  document; an assertion for a value a human would state.
