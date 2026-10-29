# preview-tests

The preview proxy's vitest suite (the host app origin, the health route, the key route's CORS and cookie, trusted preview hosts, the same-origin seam and the v0 fetch override), run on every pull request

The test suite for **preview**. It deploys nothing: its lane installs, builds and runs the tests.

|              |                      |
| ------------ | -------------------- |
| Type         | `turbo-package`      |
| Source       | `tests/preview`      |
| Package      | `@app/preview-tests` |
| Environments | `dev`: `quick-check` |

## Depends on

- (none)

## Depended on by

- (none)
