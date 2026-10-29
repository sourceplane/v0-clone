import { defineConfig } from "vitest/config";
import * as path from "node:path";

// The preview proxy's modules under `@/`, as its own tsconfig resolves them.
export default defineConfig({
  resolve: {
    alias: [
      { find: /^@\/(.*)$/, replacement: `${path.resolve(__dirname, "../../apps/preview")}/$1` },
      // Next's `server-only` guard has nothing to guard in a test.
      { find: "server-only", replacement: path.resolve(__dirname, "src/stubs/server-only.ts") },
    ],
  },
  test: {
    include: ["src/**/*.test.ts"],
    environment: "node",
  },
});
