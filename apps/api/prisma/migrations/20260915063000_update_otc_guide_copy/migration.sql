-- Sync guide.otc copy with discount-settlement semantics (defaults updated in #21).
UPDATE "app_content_entries"
SET
  "body" = 'The market quote is for reference only. Purchases settle at the discount settlement price shown in the trade dialog. Enter quantity and the 4-digit transaction key; orders stay Pending Review until approved and appear in holdings only after approval.',
  "updatedAt" = CURRENT_TIMESTAMP
WHERE "module" = 'TRADING'
  AND "key" = 'guide.otc'
  AND "locale" = 'en';

UPDATE "app_content_entries"
SET
  "title" = 'ओटीसी ट्रेडिंग',
  "body" = 'बाज़ार भाव केवल संदर्भ के लिए है। खरीद ट्रेड डायलॉग में दिखाए गए डिस्काउंट निपटान मूल्य पर होती है। मात्रा और 4 अंकों की लेनदेन कुंजी दर्ज करें; स्वीकृति तक समीक्षा लंबित रहती है और उसके बाद ही होल्डिंग में दिखती है।',
  "updatedAt" = CURRENT_TIMESTAMP
WHERE "module" = 'TRADING'
  AND "key" = 'guide.otc'
  AND "locale" = 'hi';
