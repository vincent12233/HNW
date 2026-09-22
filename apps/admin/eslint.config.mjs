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
    "tmp/**",
    "next-env.d.ts",
  ]),
  {
    settings: {
      react: {
        // eslint-plugin-react 7.37 still autodetects the React version via
        // removed ESLint 10 RuleContext APIs (getFilename). Pinning the version
        // skips that path so react/* rules work again until upstream
        // jsx-eslint/eslint-plugin-react#4022 ships.
        version: "19.3.0",
      },
    },
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
