import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const indexAliases: Record<string, string> = {
  NIFTY50: 'NIFTY 50',
  BANKNIFTY: 'NIFTY BANK',
  'NIFTY 50': 'NIFTY 50',
  'NIFTY BANK': 'NIFTY BANK',
  SENSEX: 'SENSEX',
};

async function main() {
  const symbols = process.argv.slice(2).map((value) => value.trim()).filter(Boolean);
  if (symbols.length === 0) symbols.push('RELIANCE');

  const packageName =
    process.env.INDIA_STOCK_MCP_PACKAGE?.trim() || 'india-stock-mcp';
  const command =
    process.env.INDIA_STOCK_MCP_COMMAND?.trim() ||
    (process.platform === 'win32' ? 'npx.cmd' : 'npx');

  const client = new Client({
    name: 'india-trading-platform-smoke',
    version: '1.0.0',
  });
  const transport = new StdioClientTransport({
    command,
    args: ['--no-install', packageName],
    stderr: 'pipe',
  });

  try {
    await client.connect(transport);
    const tools = await client.listTools();
    const names = new Set(tools.tools.map((tool) => tool.name));
    if (!names.has('get_quote') || !names.has('get_index')) {
      throw new Error('required market quote tools are not available');
    }

    const output: Array<Record<string, unknown>> = [];
    const failures: Array<{ symbol: string; error: string }> = [];

    for (const requested of symbols) {
      const normalized = requested.toUpperCase();
      const index = indexAliases[normalized];
      const tool = index ? 'get_index' : 'get_quote';
      const result = await client.callTool({
        name: tool,
        arguments: index ? { index } : { symbol: normalized },
      });

      const text = Array.isArray(result.content)
        ? result.content
            .filter(
              (item): item is { type: 'text'; text: string } =>
                item.type === 'text' && typeof item.text === 'string',
            )
            .map((item) => item.text)
            .join('\n')
        : '';

      if (result.isError || text.startsWith('Error:')) {
        failures.push({
          symbol: requested,
          error: text.replace(/^Error:\s*/, '') || `${tool} returned an MCP error`,
        });
        continue;
      }

      try {
        const quote = JSON.parse(text) as Record<string, unknown>;
        const price = quote.price ?? quote.last ?? quote.lastPrice;
        if (typeof price !== 'number' || price <= 0) {
          failures.push({ symbol: requested, error: 'invalid price' });
          continue;
        }

        output.push({
          requestedSymbol: requested,
          symbol: quote.symbol ?? quote.index ?? requested,
          price,
          changePct: quote.changePct ?? quote.percentChange ?? null,
          volume: quote.volume ?? null,
          tool,
        });
      } catch (error) {
        failures.push({
          symbol: requested,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    console.log(JSON.stringify({ quotes: output, failures }, null, 2));
    if (failures.length > 0) process.exitCode = 1;
  } finally {
    await client.close().catch(() => undefined);
  }
}

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`India Stock MCP smoke failed: ${message}`);
  process.exitCode = 1;
});
