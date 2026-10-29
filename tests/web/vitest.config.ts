import { defineConfig } from "vitest/config";
import * as path from "node:path";

// The host app's modules under `@/`, as its own tsconfig resolves them.
const web = path.resolve(__dirname, "../../apps/web");

export default defineConfig({
  resolve: {
    alias: [
      { find: /^@\/(.*)$/, replacement: `${web}/$1` },
      // Next's `server-only` guard has nothing to guard in a test.
      { find: "server-only", replacement: path.resolve(__dirname, "src/stubs/server-only.ts") },
    ],
  },
  test: {
    include: ["src/**/*.test.ts", "src/**/*.test.tsx"],
    environment: "node",
  },
});
