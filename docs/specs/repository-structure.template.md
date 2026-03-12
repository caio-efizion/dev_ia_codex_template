# Repository Structure

## Template Layout

```text
ai/
docs/
tasks/
runtime/
src/
tests/
```

## Code Layout

```text
src/
  modules/
    {{MODULE_FOLDER}}/
      domain/
      application/
      infrastructure/
      interface/
  shared/
  jobs/
```

## Rules

1. route or transport entrypoints stay thin
2. repositories live with the owning module
3. shared code remains business-agnostic
4. runtime outputs do not live beside source files
