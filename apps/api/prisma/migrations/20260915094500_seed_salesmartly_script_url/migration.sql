-- Seed the production SaleSmartly widget script for customer support
-- (deposit contact + floating FAB). Only fills empty CMS values.
UPDATE "AppContentEntry"
SET
  body = 'https://plugin-code.salesmartly.com/js/project_829333_860505_1789464929.js',
  "updatedAt" = CURRENT_TIMESTAMP
WHERE module = 'SUPPORT'
  AND key = 'salesmartly_script_url'
  AND TRIM(COALESCE(body, '')) = '';
