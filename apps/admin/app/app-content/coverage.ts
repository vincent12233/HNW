export type SavedContentRow = {
  module: string;
  key: string;
  locale: string;
  body: string;
};

export function missingLocaleKeys(
  entries: ReadonlyArray<SavedContentRow>,
  module: string,
  keys: ReadonlyArray<string>,
  locale: "en" | "hi",
): string[] {
  const available = new Set(
    entries
      .filter(
        (entry) =>
          entry.module === module &&
          entry.locale === locale &&
          entry.body.trim().length > 0,
      )
      .map((entry) => entry.key),
  );
  return keys.filter((key) => !available.has(key));
}
