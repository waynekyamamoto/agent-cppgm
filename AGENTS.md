# Project Layout and Development Workflow

This project is a series of assignments, `PA1` through `PA9`, that build
toward a self-hosting C++11 compiler for Linux x86_64.

## Project Structure

- `pa1/`: Programming Assignment 1 - Preprocessing Tokenizer (`pptoken`)
- `pa2/`: Programming Assignment 2 - Post-Tokenizer (`posttoken`)
- `pa3/`: Programming Assignment 3 - Constant Expressions (`ctrlexpr`)
- `pa4/`: Programming Assignment 4 - Macro Processor (`macro`)
- `pa5/`: Programming Assignment 5 - Preprocessor (`preproc`)
- `pa6/`: Programming Assignment 6 - C++ Grammar Recognizer (`recog`)
- `pa7/`: Programming Assignment 7 - Namespace Declarations (`nsdecl`)
- `pa8/`: Programming Assignment 8 - Namespace Initialization (`nsinit`)
- `pa9/`: Programming Assignment 9 - Code Generation (`cy86`)
- `doc/`: Documentation and reference materials.

## Grammar Files and Extras

Assignments PA6 through PA9 include grammar files (`.gram`) and sometimes additional resources in `grammar/` or `extras/` directories. These are provided as part of the assignment specification and should be referenced during implementation.

## Development Workflow

To facilitate code reuse and maintain a single source of truth for the
compiler's implementation, the project uses a central `dev/` build with
assignment-local source symlinks.

- `dev/`: Contains the real assignment entry points, one file per tool
  (for example `dev/pptoken.cpp` and `dev/posttoken.cpp`).
- `dev/src/`: Contains all shared compiler components and shared headers.
- `paN/<tool>.cpp`: Each assignment contains a committed symlink to the real
  entry point in `../dev/`. This keeps the assignment package shape familiar
  without duplicating source.

### Working on an Assignment

1. **Implement Features**: 
   - Modify the corresponding tool entry point in `dev/`.
   - Add new shared components in `dev/src/`.
2. **Central Shared Build**:
   - The canonical executables are built by `dev/Makefile`.
   - Assignment Makefiles delegate builds to `dev/Makefile` rather than
     compiling shared sources themselves.
   - Shared objects are kept in a shared `obj/` cache so later assignments
     reuse already-built common code.
   - The assignment Makefiles take a lock before invoking the central build so
     concurrent assignment builds do not trample each other in `obj/`.
3. **Automatic Dependency Tracking**: 
   - Header changes (`.h` files) are automatically detected, ensuring that only the necessary source files are recompiled when you modify an interface.
4. **Build and Verify**:
   From within the specific assignment directory (e.g., `pa1/`):
   ```bash
   make       # Build the application
   make test  # Run the test suite
   ```
   Each assignment directory also contains a committed `course` symlink to
   `../tests/course`, so supplemental shared tests are available as
   `course/paN/` from inside `paN/`.

### Regression Testing

As you progress through the assignments, it is crucial to ensure that changes
made for a new assignment do not break previous ones.

- `make build` from the project root builds the canonical tools once through
  `dev/Makefile`.
- `make test` from the project root runs `make build` first, then runs the
  assignment suites against the already-built tools with rebuilds skipped.
- After completing `paN`, run `make test-through-paN` from the **project
  root** to follow the same build-first path and then test assignments from
  `pa1` through `paN`.
- Example: after finishing `pa5`, run `make test-through-pa5`.
- Treat this regression run as part of finishing the assignment, not as an
  optional cleanup step.

### Version Control (Git)

It is highly recommended to track your progress using Git. Committing
frequently makes shared-code refactors safer and makes regressions much easier
to unwind.

**Commit Strategy**: 
- Commit after successfully implementing a new feature or passing a new test case.
- Always commit before starting the next assignment (`pa(N+1)`), ensuring your
  workspace is clean and `make test-through-paN` passes from the root.
- Example: `git commit -am "pa1: implement trigraph replacement"`

### Assignment Retrospectives

After completing each assignment, add a `RETRO.md` file in the corresponding
`paN/` directory and commit it with the assignment work or immediately after.
Each retrospective should cover:

- What went well.
- What went poorly.
- Suggestions for improving the assignment, starter code, tests, or reference material.

### Suggestions for Success

- Reuse and extend code from previous assignments instead of starting each
  assignment from scratch. The project is designed to build cumulatively.
- Include extra context in error cases when practical, especially filenames,
  line numbers, and the specific condition that failed. Better diagnostics make
  debugging and regression triage much easier.
- Periodically simplify, reorganize, and refactor shared code as the project
  grows so the implementation stays manageable across later assignments.
- Follow the checked-in tests closely. Implement behavior to match the current
  test suite where possible, even if a broader feature set or a newer standard
  interpretation would behave differently.
- Do not implement features "ahead" of the assignment if doing so changes
  behavior that the current tests expect.
- If a conflict between the tests, reference behavior, and intended design
  truly cannot be resolved cleanly, choose the path that keeps the assignment
  moving forward and document the conflict in `RETRO.md`.

### Assignment Integrity

- Implement the assignment yourself in `dev/` and `dev/src/`. The goal is to
  make the student tool behave correctly, not to make the test harness report
  success by other means.
- Do not edit checked-in `.ref` outputs, `.ref.*` sidecars, or test inputs in
  order to match an incomplete implementation.
- Do not bypass, skip, narrow, or weaken the required tests. Do not modify
  Makefiles, compare scripts, or test runners just to avoid exercising failing
  behavior.
- Do not shell out from the student implementation to reference binaries,
  production compilers, prior solutions, or other external programs to produce
  the assignment's required output. The reference tools are for observation and
  fixture generation only, not for delegation.
- Do not hardcode expected answers for specific test files or special-case
  behavior by test name. Implement the underlying language feature or rule.
- If you discover a genuine bug or conflict in the harness or assignment
  materials, note it in `RETRO.md` and continue implementing the assignment
  yourself rather than treating test or harness edits as the solution.

## Tools and References

- **Reference Implementations**: Each `paN` directory contains a compiled
  reference binary (e.g., `pptoken-ref`). Use it to inspect expected behavior
  and to regenerate assignment-local fixtures in `paN/tests/` via
  `make ref-test`.
- **Local Test Suites**: The original assignment test suites live in
  `paN/tests/`. They include input files (`.t`), reference outputs (`.ref`),
  and exit statuses. `make ref-test` only regenerates these local fixtures.
- **Shared Supplemental Tests**: Additional shared tests live in
  `tests/course/paN/` and are reachable from inside each assignment directory
  as `course/paN/`. `make test` runs both `paN/tests/` and `course/paN/`.
- **Where to Add New Shared Tests**: If you add new user-authored or
  supplemental tests, put them in `tests/course/paN/` rather than
  `paN/tests/`.
- **Test Authority**: Prefer the checked-in tests for the current assignment
  over speculative improvements, broader feature support, or newer-standard
  behavior when those would cause regressions. In practice, implement to the
  tests where possible.
- **Authoring Rule for Shared Tests**: Do not bulk-regenerate the checked-in
  `.ref` files under `tests/course/paN/` from the local `*-ref` binaries.
  Those imported fixtures are authoritative and may intentionally cover edge
  cases where the reference binaries are not the oracle. Update them only with
  an intentional content change.
- **C++ Standard**: The project targets the C++11 standard (N3485), available in the `doc/` directory.
