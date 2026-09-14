-- CreateEnum
CREATE TYPE "AppContentModule" AS ENUM ('HOME', 'DEPOSIT', 'SUPPORT', 'TRADING');

-- CreateTable
CREATE TABLE "app_content_entries" (
    "id" TEXT NOT NULL,
    "module" "AppContentModule" NOT NULL,
    "key" TEXT NOT NULL,
    "title" TEXT,
    "body" TEXT NOT NULL,
    "locale" TEXT NOT NULL DEFAULT 'en',
    "metadata" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "app_content_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "deposit_receiving_accounts" (
    "id" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "method" TEXT NOT NULL,
    "accountName" TEXT,
    "bankName" TEXT,
    "accountNumber" TEXT,
    "ifsc" TEXT,
    "upiId" TEXT,
    "notes" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "deposit_receiving_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "app_content_entries_module_isActive_idx" ON "app_content_entries"("module", "isActive");

-- CreateIndex
CREATE INDEX "app_content_entries_module_sortOrder_idx" ON "app_content_entries"("module", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "app_content_entries_module_key_locale_key" ON "app_content_entries"("module", "key", "locale");

-- CreateIndex
CREATE INDEX "deposit_receiving_accounts_isActive_sortOrder_idx" ON "deposit_receiving_accounts"("isActive", "sortOrder");

-- Seed default operable content from current APP hardcodes
INSERT INTO "app_content_entries" ("id", "module", "key", "title", "body", "locale", "isActive", "sortOrder", "updatedAt") VALUES
('ops-home-banner-title-en', 'HOME', 'banner.title', NULL, 'Track live markets & place orders on the go', 'en', true, 10, CURRENT_TIMESTAMP),
('ops-home-banner-subtitle-en', 'HOME', 'banner.subtitle', NULL, 'Explore equities, institutional offers, OTC and IPOs', 'en', true, 20, CURRENT_TIMESTAMP),
('ops-home-markets-banner-title-en', 'HOME', 'markets.banner.title', NULL, 'Track live markets & place orders on the go', 'en', true, 30, CURRENT_TIMESTAMP),
('ops-home-markets-banner-subtitle-en', 'HOME', 'markets.banner.subtitle', NULL, 'Live prices, company logos and secure execution', 'en', true, 40, CURRENT_TIMESTAMP),
('ops-deposit-instructions-en', 'DEPOSIT', 'instructions', 'Deposit instructions', 'Please contact online support for deposit instructions. Finance will credit your account after payment is confirmed.', 'en', true, 10, CURRENT_TIMESTAMP),
('ops-deposit-chat-preset-en', 'DEPOSIT', 'chat_preset', NULL, 'Hello, I would like to add money to my account.', 'en', true, 20, CURRENT_TIMESTAMP),
('ops-deposit-reject-message-en', 'DEPOSIT', 'api_reject_message', NULL, 'Please contact online support for deposit instructions. Finance will credit your account after payment is confirmed.', 'en', true, 30, CURRENT_TIMESTAMP),
('ops-support-greeting-en', 'SUPPORT', 'greeting', NULL, 'You are contacting online customer service inside the app.', 'en', true, 10, CURRENT_TIMESTAMP),
('ops-support-hours-en', 'SUPPORT', 'hours', NULL, 'Support is available during business hours via in-app chat.', 'en', true, 20, CURRENT_TIMESTAMP),
('ops-support-chat-help-en', 'SUPPORT', 'chat_preset.help', NULL, 'Hello, I need help with my account.', 'en', true, 30, CURRENT_TIMESTAMP),
('ops-support-script-url', 'SUPPORT', 'salesmartly_script_url', NULL, '', 'en', true, 40, CURRENT_TIMESTAMP),
('ops-support-quick-1-zh', 'SUPPORT', 'quick_reply.deposit', '入金指引', '您好，请按客服提供的存款方式付款并发送付款凭证。客服会转交信息，财务核实实际到账后为账户上分。', 'zh', true, 50, CURRENT_TIMESTAMP),
('ops-support-quick-2-zh', 'SUPPORT', 'quick_reply.withdrawal', '提现跟进', '您的提现申请已收到，财务会根据订单号核对并处理。', 'zh', true, 60, CURRENT_TIMESTAMP),
('ops-support-quick-3-zh', 'SUPPORT', 'quick_reply.kyc', 'KYC 审核', '请上传清晰的 Aadhaar 或 PAN 文件，业务员会尽快审核 KYC。', 'zh', true, 70, CURRENT_TIMESTAMP),
('ops-support-quick-4-zh', 'SUPPORT', 'quick_reply.general', '通用核查', '请提供手机号、客户姓名和问题截图，我们马上为您核查。', 'zh', true, 80, CURRENT_TIMESTAMP),
('ops-trading-inst-empty-title', 'TRADING', 'institutional.empty_title', NULL, 'No institutional offers available', 'en', true, 10, CURRENT_TIMESTAMP),
('ops-trading-inst-empty-sub', 'TRADING', 'institutional.empty_subtitle', NULL, 'Stocks will appear here when live market data is available.', 'en', true, 20, CURRENT_TIMESTAMP),
('ops-trading-otc-empty-title', 'TRADING', 'otc.empty_title', NULL, 'No OTC opportunities available', 'en', true, 30, CURRENT_TIMESTAMP),
('ops-trading-otc-empty-sub', 'TRADING', 'otc.empty_subtitle', NULL, 'Backend-approved opportunities will appear here during the trading session.', 'en', true, 40, CURRENT_TIMESTAMP),
('ops-trading-ipo-confirm', 'TRADING', 'ipo.confirm_template', NULL, 'Submit IPO application {current} of {max}?\n\nPayment is automatic after allotment if your account has sufficient funds.', 'en', true, 50, CURRENT_TIMESTAMP),
('ops-trading-guide-inst', 'TRADING', 'guide.institutional', 'Institutional offers', 'Institutional offers are operator-listed opportunities. Review price, eligibility and terms before submitting. An application is not a settled holding until approved.', 'en', true, 60, CURRENT_TIMESTAMP),
('ops-trading-guide-otc', 'TRADING', 'guide.otc', 'OTC trading', 'OTC purchases require quantity and transaction-key confirmation, remain Pending Review until approved, and appear in holdings only after approval.', 'en', true, 70, CURRENT_TIMESTAMP),
('ops-trading-guide-ipo', 'TRADING', 'guide.ipo', 'IPO applications', 'IPO applications may be pending, allocated or rejected. An allocation can create an outstanding payment obligation. Check notices before assuming shares are sellable.', 'en', true, 80, CURRENT_TIMESTAMP);
