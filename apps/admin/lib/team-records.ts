type Row = Record<string, unknown>;

export async function loadTeamRecords(
  fetchPage: (page: number) => Promise<unknown>,
  isActive: () => boolean = () => true,
): Promise<Row[]> {
  const records: Row[] = [];
  for (let page = 1; ; page++) {
    if (!isActive()) return [];
    const response = await fetchPage(page);
    if (Array.isArray(response)) return response;
    if (!response || typeof response !== 'object') throw new Error('Invalid team response');
    const envelope = response as { data?: Row[]; items?: Row[]; totalPages?: number };
    const rows = envelope.data ?? envelope.items;
    if (!Array.isArray(rows)) throw new Error('Invalid team records');
    records.push(...rows);
    const totalPages = envelope.totalPages ?? 1;
    if (!Number.isInteger(totalPages) || totalPages < 0) throw new Error('Invalid page count');
    if (page >= totalPages) return records;
    if (!rows.length) throw new Error('Incomplete team records');
  }
}
