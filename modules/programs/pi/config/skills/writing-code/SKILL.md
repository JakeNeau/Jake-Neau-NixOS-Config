---
name: writing-code
description: Use before writing or changing any code in any language. The house style for design, functions, types, data, and names: deep modules, composed functions, APIs that are hard to misuse, immutable by default, guard clauses, pipelines, descriptive names.
---

# Writing code

Write the smallest, clearest code that does the job, shaped so a reader's first
guess is right. The rules below say how; each gives its reason so you can apply
it to cases the examples don't show. When two rules conflict, the earlier one
wins.

## Scope

- Keep to what was asked. Deliver the task at the scope intended; propose
  anything beyond it with `ask_user` instead of doing it.
- Use the minimum complexity the task needs. Skip handling for cases that
  cannot happen, helpers for one-time operations, and extra files.
- Delete freely. Unused code goes; version control keeps history.

## Design

### Least surprise
A reader's first guess about what a name, function, or module does should be
right. Why: every surprise costs a reader a trip into the body, and surprises
compound into bugs.

```rust
// surprising: a getter that writes
fn config(&mut self) -> &Config { self.load_if_stale(); &self.config }

// expected: the name says it refreshes
fn refreshed_config(&mut self) -> &Config { self.load_if_stale(); &self.config }
```

### Deep modules
Give a module a small interface over a large amount of functionality. Why: a
caller pays for the interface on every use and for the implementation never;
depth is where complexity hides without spreading.

```ts
// shallow: five calls expose every step
const h = openFile(p); setMode(h, "r"); const b = allocate(size(h)); read(h, b); close(h);

// deep: one call, the steps live inside
const bytes = readFile(p);
```

### APIs hard to misuse
Make the easy call the correct call. Represent invalid states so they cannot
be built, and enforce required steps with types rather than documentation.
Why: a rule in a doc comment is followed sometimes; a rule in a type is
followed always.

```rust
// misusable: caller may forget connect()
let c = Client::new(url); c.send(req)?;

// enforced: send exists only on a connected client
let c = Client::new(url).connect()?; c.send(req)?;
```

### Composed functions
Each function does one thing at one level of abstraction and reads as a
sequence of well-named calls. Why: a function that mixes levels forces the
reader to switch between "what" and "how" mid-stream.

```python
def publish(post):
    validate(post)
    rendered = render(post)
    store(rendered)
    notify_subscribers(post)
```

Keep one place for each fact. A rule that lives in two functions drifts.

### Top-down file order
Put each function above the ones it calls, so a file reads from the entry
point down. Why: a reader meets the summary before the detail.

### SOLID
- One reason to change per unit.
- Extend by adding code, not editing working code.
- A subtype works wherever its parent does.
- Small, focused interfaces; a caller depends only on what it uses.
- Depend on abstractions, not concrete implementations, at module edges.

## Functions

### Command or query
A function either changes state or returns information. Why: a query with
side effects cannot be called freely, and a command that returns data tempts
callers into relying on both.

```ts
// both: pops and reports
function next(): Item { const i = queue.shift(); log(i); return i; }

// split
function peek(): Item { return queue[0]; }
function advance(): void { log(queue.shift()); }
```

### Side effects
Keep effects at the edges. Mutating an input the caller handed you is fine
when the name says so; hidden state (globals, caches, clocks) is not.

### Tell, don't ask
Give an object the work instead of pulling its data out to decide for it.
Why: the decision then lives beside the data it depends on.

```python
# asking
if account.balance >= amount and not account.frozen: account.balance -= amount

# telling
account.withdraw(amount)
```

### Accept the general, return the specific
Take the broadest parameter type that works (an iterator, a trait, an
interface) and return the most concrete type you have. Why: broad inputs serve
more callers; concrete outputs give callers more to work with.

### Guard clauses
Handle the exceptional cases at the top and return, so the main path sits at
one level of indentation.

```rust
fn price(item: &Item) -> Result<Cents, Error> {
    let Some(base) = item.base_price else { return Err(Error::Unpriced) };
    if item.discontinued { return Err(Error::Discontinued) }
    Ok(apply_tax(base))
}
```

### Pipelines
Prefer filter, map, and fold over hand-written loops. Why: a pipeline names
each transformation; a loop makes the reader reconstruct it.

```ts
const total = orders.filter(isPaid).map(amount).reduce(add, 0);
```

### Named arguments
When a call's arguments are not clear at the call site, take a struct or
options object.

```ts
resize(img, { width: 300, height: 200, keepAspect: true });  // not resize(img, 300, 200, true)
```

## Types and data

- Data is immutable by default; make everything const that can be. Why:
  a value that cannot change needs no reasoning about when it changes.
- Use types to remove code. Let the compiler rule out a state instead of
  checking for it at runtime: an enum over a string, a newtype over a bare
  integer, a non-empty list over a list plus a check.
- Name every constant. A bare number in logic has no reason attached.
- Use typed errors wherever the language allows, so a caller can match on
  what went wrong.

```rust
const RETRY_LIMIT: u8 = 3;
enum Fetch { Ok(Body), Timeout, Unauthorized }  // not Result<Body, String>
```

## Names

- Fully descriptive, with no abbreviations unless the project's glossary has
  them. A reader should not need the body to know what a function does.
- A function that cannot be named fully does too much; split it.
- Naming is where you are weakest. When a good name is hard to find, ask the
  user for one with `ask_user` rather than settling.

## Decision points

- Simplicity versus depth: a deep module is allowed its internal complexity;
  the simplicity rule governs its interface and the caller's code.
- Immutability versus mutating inputs: prefer returning a new value; mutate an
  input only when the function's name makes the mutation obvious.
- DRY versus clarity: one place per fact, but two similar lines beat a
  helper that exists only to merge them.
