import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // Upstream formats with oxfmt and runs no ESLint at all. These rules —
    // the React Compiler rules and the TypeScript config of
    // eslint-config-next 16 — flag the example's code as written, which is
    // kept; each is off by name, and only in the files that need it.
    files: ["components/ai-elements/prompt-input.tsx", "components/ai-elements/web-preview.tsx"],
    rules: {
      // The AI Elements prompt input mirrors its controlled value into
      // refs and state, and the web preview mirrors its URL into the input.
      "react-hooks/refs": "off",
      "react-hooks/set-state-in-effect": "off",
      // The speech-recognition shims (`any` for the browser's untyped API).
      "@typescript-eslint/no-explicit-any": "off",
    },
  },
  globalIgnores([".next/**", ".open-next/**", ".wrangler/**", "next-env.d.ts", "cloudflare-env.d.ts"]),
]);
