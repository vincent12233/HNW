import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
  {
    rules: {
      // Existing admin UI uses `any` at API boundaries; keep visible as warnings.
      "@typescript-eslint/no-explicit-any": "warn",
      "@typescript-eslint/no-unused-vars": [
        "warn",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
        },
      ],
      // Admin pages intentionally load list data on mount via useEffect → setState.
      // The React Compiler rule rejects that pattern; keep CI green and revisit
      // page-by-page with query libraries when we standardize data fetching.
      "react-hooks/set-state-in-effect": "off",
      // Many mount-once loaders omit unstable function identities on purpose.
      "react-hooks/exhaustive-deps": "warn",
    },
  },
]);

export default eslintConfig;
