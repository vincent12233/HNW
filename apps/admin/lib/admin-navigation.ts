/** Match manager views independently of unrelated filters and query order. */
export function findNavigationItem<T extends { key: string }>(items: T[], activeKey: string): T | undefined {
  const [activePath, activeQuery = ""] = activeKey.split("?");
  const currentParams = new URLSearchParams(activeQuery);
  const candidates = items.filter(({ key }) => {
    const [path] = key.split("?");
    return activePath === path || activePath.startsWith(`${path}/`);
  });

  return (
    candidates.find(({ key }) => {
      const [, query] = key.split("?");
      return query && Array.from(new URLSearchParams(query)).every(([name, value]) => currentParams.get(name) === value);
    }) ||
    candidates.find(({ key }) => !key.includes("?")) ||
    // The team page defaults to the team view when no view is supplied.
    (currentParams.has("view") ? undefined : candidates.find(({ key }) => key.endsWith("?view=team")))
  );
}
