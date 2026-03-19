# Skill: Code Generation (Phase 3)

**Category:** sdlc
**Phase:** 3 of 8
**Requires:** Supermodel API (scripts/supermodel.sh)
**System:** Big Iron — AI-Native SDLC

## Purpose

Write code that is structurally consistent with the existing codebase. Use the graph to pull exact signatures, import paths, and call conventions before writing a single line — never guess what already exists.

---

## Procedure

### Step 1 — Fetch signatures for all touched symbols

For every function you will call, override, or extend:

```
POST /v1/graphs/call  (search nodes)
  name: "<symbol name>"
  include_signature: true
```

Record: parameter names, types, return type, module path. Do not infer these from memory or documentation — get them from the graph.

### Step 2 — Resolve imports

```
POST /v1/graphs/dependency
  module: "<target file>"
```

Identify:
- What is already imported in the target file
- Which module exports the symbols you need to call
- The correct import path (relative or absolute, per project convention)

Do not add duplicate imports. Do not guess module paths.

### Step 3 — Check for existing implementations

Before writing a new utility function, check if it already exists:

```
POST /v1/graphs/call  (search nodes)
  name: "<candidate function name>"
  fuzzy: true
```

If a match exists, use it. Dead code and duplicate implementations are caught at Phase 4, but it's cheaper to avoid them here.

### Step 4 — Write the code

Now write. Use the signatures and imports from Steps 1–3 exactly as retrieved. Do not adapt them.

Conventions:
- Match the naming style of the file you're modifying (query a neighbor symbol if unsure)
- Match error handling patterns (check a sibling function in the same module)
- Do not add abstraction layers not present in the Phase 2 arch review

### Step 5 — Verify call graph consistency

After writing, mentally trace: does every function call you made match a real symbol in the graph? If you introduced a call to a symbol that didn't exist before (a new function), confirm it is defined in the same changeset.

---

## Verification

- [ ] Every external function called has a confirmed signature from the graph
- [ ] No import paths guessed — all resolved via dependency graph
- [ ] No duplicate implementations introduced (checked via fuzzy symbol query)
- [ ] All new symbols are defined within this changeset (no dangling calls)
- [ ] Code matches naming and error-handling style of surrounding module

---

## Pitfalls

- **Writing "obviously correct" signatures from memory.** Parameter order, optional flags, and return types change. Always query.
- **Guessing import paths.** Especially in monorepos with deep nesting. Always use the dependency graph.
- **Adding a convenience wrapper around an existing function.** Check with fuzzy search first.
- **Changing a function signature without updating callers.** The blast radius from Phase 1 lists all callers that need updating. Work through the list.

---

## Token Notes

The graph gives you signatures and imports with zero file reads. Use that. Only open a file when you are ready to write to it — not to read context.
