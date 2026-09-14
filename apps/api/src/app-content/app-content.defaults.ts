import { AppContentModule } from '../generated/prisma/enums';

type DefaultContent = {
  module: AppContentModule;
  key: string;
  title?: string | null;
  body: string;
  locale?: string;
  sortOrder?: number;
  isActive?: boolean;
};

const privacyDocument = {
  effective: 'Effective 13 August 2026  •  Version 1.0',
  sections: [
    {
      heading: '1. Who we are',
      body: 'This policy explains how the operator of the India Trading application (India Trading, we, us or our) processes personal data when you register for, access or use the application, website, customer support and related services. The operator’s final legal name, registered address and grievance contact must be displayed in About Us before public release.',
    },
    {
      heading: '2. Data we collect',
      body: 'We may collect your name, Indian mobile number, email address, date of birth, address, tax and KYC identifiers and documents, profile image, bank-account details, account balances, orders, transactions, holdings and settlement records. We also collect device, IP address, login and security logs, notification preferences, customer-support messages and files you choose to send. If you link Google, we receive the verified email and account identifier needed for sign-in.',
    },
    {
      heading: '3. Biometrics',
      body: 'Face ID or fingerprint verification is performed by your device operating system. India Trading does not receive or store your biometric template. When you enable quick login, the application stores a revocable, time-limited login credential in device storage. Resetting your password invalidates that credential and you must enable quick login again.',
    },
    {
      heading: '4. Why we use data',
      body: 'We use personal data to create and protect accounts; authenticate users; complete KYC and other required checks; provide market information; accept, review, process and settle transactions under the applicable product workflow; maintain bank-account records; send OTPs and service notifications; provide support; investigate fraud, abuse and security incidents; maintain audit records; improve reliability; and comply with lawful obligations.',
    },
    {
      heading: '5. Consent and required processing',
      body: 'We request consent where required and provide a way to withdraw it. Withdrawal does not affect processing already completed and may prevent us from providing functions that require the withdrawn data. Some information remains necessary to perform your requested service, secure the platform, resolve disputes or meet legal and record-keeping duties.',
    },
    {
      heading: '6. Who receives data',
      body: 'We may share only the information reasonably necessary with cloud and security providers, SMS/OTP providers, Google authentication, market-data providers, banks and settlement service providers, the business or support team assigned to your account, professional advisers, and competent government, regulatory or law-enforcement authorities. We do not sell personal data for money.',
    },
    {
      heading: '7. Storage, transfer and retention',
      body: 'Data may be processed in India and in other locations used by our contracted providers, subject to applicable transfer restrictions. We retain data only for the service, security, dispute-resolution and legal periods that apply. Security and system logs are retained for at least the period required by applicable Indian cyber-security directions. Data is deleted or anonymised when it is no longer required, unless preservation is legally required.',
    },
    {
      heading: '8. Security',
      body: 'We use access controls, encrypted transport, password hashing, expiring OTPs, authentication controls, audit logging and operational safeguards appropriate to the nature of the data. No system can guarantee absolute security. Keep your password, OTP and transaction key confidential and notify Online Customer Service immediately if you suspect unauthorised access.',
    },
    {
      heading: '9. Your choices and rights',
      body: 'Subject to applicable law, you may request information about processing, access the information made available to you, correct inaccurate or incomplete data, request erasure where retention is not required, withdraw consent, nominate another person to exercise applicable rights, and raise a grievance. You can update available profile fields or contact Online Customer Service in the application. We may verify identity before completing a request.',
    },
    {
      heading: '10. Children',
      body: 'The service is intended only for persons aged 18 or older. Do not register or provide personal data if you are under 18.',
    },
    {
      heading: '11. Updates and contact',
      body: 'We may update this policy and will show the new effective date and provide any notice required by law. For privacy questions, rights requests or grievances, use Online Customer Service in the application. The operator must publish the designated grievance contact and formal service address in About Us before launch.',
    },
  ],
};

const termsDocument = {
  effective: 'Effective 13 August 2026  •  Version 1.0',
  sections: [
    {
      heading: '1. Agreement and eligibility',
      body: 'These Terms govern your use of India Trading. By creating an account or using the service, you agree to them and the Privacy Policy. You must be at least 18, legally capable of contracting, provide accurate information, complete required verification and use the service only for yourself unless the operator expressly authorises another arrangement.',
    },
    {
      heading: '2. Account security',
      body: 'You are responsible for protecting your password, OTP, transaction key and registered device. Google and biometric quick login are optional. Device biometrics only unlock a stored quick-login credential; they do not replace transaction authorisation where a transaction key or another confirmation is required. Report suspected unauthorised access immediately.',
    },
    {
      heading: '3. Services and product workflows',
      body: 'The application provides market information and product-specific transaction workflows. Ordinary-stock orders follow the market hours, price, order-state and settlement rules disclosed in the application. Institutional offers, IPOs and OTC products are available only through Trading and use their separately displayed eligibility, pricing, allocation, review and settlement rules. OTC purchases require quantity and transaction-key confirmation, remain Pending Review until approved by the backend, and appear in the relevant completed position only after approval. Institutional and OTC products have no minimum quantity unless a specific product disclosure states otherwise.',
    },
    {
      heading: '4. Execution and settlement disclosure',
      body: 'The application does not itself connect an order directly to a securities exchange. Transactions are processed and settled through the operator’s disclosed backend arrangements. A displayed real-time or reference price does not by itself prove exchange execution. Before accepting transactions, the operator must clearly identify the contracting entity, execution or allocation model, custody or ownership record, settlement timing, cancellation rules and user recourse for each product.',
    },
    {
      heading: '5. Orders and authorisation',
      body: 'Review the instrument, side, quantity, price basis, charges and total before confirming. Submitting an instruction authorises the applicable workflow but does not guarantee acceptance, execution, allocation or approval. Instructions may be rejected or remain pending because of account status, market hours, price availability, insufficient balance, risk controls, product availability, compliance review, technical interruption or other disclosed rules. Completed or settled instructions may not be reversible.',
    },
    {
      heading: '6. Market data and risk',
      body: 'Prices, charts, news and indicators are provided for information and may be delayed, unavailable, corrected or differ from a final transaction or settlement price. Investments can lose value, allocation may be unavailable and past performance is not a guarantee. India Trading does not guarantee profits or uninterrupted access. Nothing in the application is personal investment, tax or legal advice unless expressly identified as such by an authorised professional.',
    },
    {
      heading: '7. Money, bank accounts, charges and taxes',
      body: 'Add Funds opens Online Customer Service; it is not an automatic deposit or payment confirmation. Follow only verified in-app instructions and confirm that funds are credited to your account record. A bank account you add is recorded in the backend without a separate approval step, but ownership or compliance checks may still be required before withdrawal or settlement. Applicable prices, fees, taxes, deductions and settlement amounts must be shown or otherwise disclosed before they are charged.',
    },
    {
      heading: '8. Prohibited use',
      body: 'You must not impersonate another person, provide false KYC or bank data, share or misuse credentials, manipulate transactions or prices, exploit errors, interfere with security, introduce malicious code, use unlawful funds, evade applicable restrictions, scrape protected services or use the platform for fraud, market abuse or any illegal purpose.',
    },
    {
      heading: '9. Suspension and termination',
      body: 'We may restrict or suspend access when reasonably necessary for security, suspected fraud, incomplete verification, legal compliance, misuse, material breach, system protection or a valid authority request. Where permitted, we will provide notice and a route to contact support. Termination does not remove accrued payment, settlement, record-keeping or dispute obligations.',
    },
    {
      heading: '10. Availability and liability',
      body: 'We use reasonable care to operate the service but availability can be affected by networks, devices, data providers, banking systems and events outside our control. To the maximum extent permitted by law, the operator is not liable for indirect or consequential loss. Nothing in these Terms excludes liability or consumer rights that cannot lawfully be excluded. Product-specific disclosures prevail if they provide greater protection.',
    },
    {
      heading: '11. Changes, complaints and governing terms',
      body: 'We may change these Terms prospectively and will show the effective date and provide required notice. Raise service or transaction complaints through Online Customer Service and keep the ticket reference. Before public release, the operator must insert its legal entity name, registered address, grievance officer, applicable licence or registration details (only if actually held), governing law, courts or arbitration venue, and escalation channels in About Us and the final version of these Terms.',
    },
  ],
};

const insightArticles: Array<{
  key: string;
  titleEn: string;
  bodyEn: string;
  titleHi: string;
  bodyHi: string;
  sortOrder: number;
}> = [
  {
    key: 'article.01',
    titleEn: 'Account and KYC',
    bodyEn:
      'Register with your phone number and invitation code. Keep your login password private. Your account ID is read-only; your name can be updated in Personal Information.\n\nSubmit clear, complete Aadhaar or PAN documents through KYC Verification. Check the review status before adding a bank account. If documents are rejected, review the reason and upload corrected documents. Do not send identity documents through unsolicited messages.',
    titleHi: 'खाता और केवाईसी',
    bodyHi:
      'अपने मोबाइल नंबर और आमंत्रण कोड से पंजीकरण करें। लॉगिन पासवर्ड गोपनीय रखें। खाता आईडी बदली नहीं जा सकती; व्यक्तिगत जानकारी में नाम बदला जा सकता है।\n\nकेवाईसी सत्यापन में स्पष्ट और पूर्ण आधार या पैन दस्तावेज़ जमा करें। बैंक खाता जोड़ने से पहले समीक्षा की स्थिति देखें। अस्वीकृति पर कारण पढ़ें और सही दस्तावेज़ जमा करें। अनचाहे संदेशों में पहचान दस्तावेज़ न भेजें।',
    sortOrder: 10,
  },
  {
    key: 'article.02',
    titleEn: 'Market basics',
    bodyEn:
      'A quote is the latest available price, not a promise of execution. Quotes may be delayed or unavailable. Check the exchange, trading session and quote timestamp before placing an order.\n\nA watchlist tracks instruments; adding a symbol does not buy it. Price charts show historical market observations. They do not predict future returns.',
    titleHi: 'बाज़ार की मूल बातें',
    bodyHi:
      'भाव नवीनतम उपलब्ध कीमत है, निष्पादन की गारंटी नहीं। भाव में देरी हो सकती है या वह उपलब्ध नहीं हो सकता। ऑर्डर देने से पहले एक्सचेंज, सत्र और भाव का समय देखें।\n\nवॉचलिस्ट केवल शेयरों पर नज़र रखती है; शेयर जोड़ने से खरीद नहीं होती। चार्ट पिछले बाज़ार भाव दिखाते हैं, भविष्य के रिटर्न का अनुमान नहीं।',
    sortOrder: 20,
  },
  {
    key: 'article.03',
    titleEn: 'Order types',
    bodyEn:
      'A market order requests execution at the available price. The final price can differ from the quote, especially when liquidity is low or prices move quickly.\n\nA limit order sets the highest purchase price or lowest sale price you accept. It may fill partly or not at all. Review quantity, price, available funds and order status. An order submission is not a completed trade; check fills in Order Book and Order History.',
    titleHi: 'ऑर्डर प्रकार',
    bodyHi:
      'मार्केट ऑर्डर उपलब्ध भाव पर निष्पादन का अनुरोध करता है। कम तरलता या तेज़ बदलाव में अंतिम कीमत दिखाए गए भाव से अलग हो सकती है।\n\nलिमिट ऑर्डर खरीद की अधिकतम या बिक्री की न्यूनतम स्वीकार्य कीमत तय करता है। वह आंशिक रूप से पूरा हो सकता है या नहीं भी। मात्रा, कीमत, उपलब्ध राशि और स्थिति जाँचें। ऑर्डर भेजना पूरा हुआ ट्रेड नहीं है; ऑर्डर बुक और इतिहास में निष्पादन देखें।',
    sortOrder: 30,
  },
  {
    key: 'article.04',
    titleEn: 'Order validity',
    bodyEn:
      'DAY orders remain eligible during the trading day and expire if not filled by the session cutoff. IOC means immediate-or-cancel: any unfilled remainder is cancelled. FOK means fill-or-kill: the entire quantity must execute immediately or the order is cancelled.\n\nOnly use validity options supported by the selected order screen. A cancellation request may race with a fill. Refresh the order status and holdings before submitting a replacement.',
    titleHi: 'ऑर्डर वैधता',
    bodyHi:
      'DAY ऑर्डर ट्रेडिंग दिन तक मान्य रहता है और सत्र समाप्त होने पर अधूरा हिस्सा समाप्त हो जाता है। IOC में तुरंत पूरा न हुआ हिस्सा रद्द होता है। FOK में पूरी मात्रा तुरंत पूरी होनी चाहिए, अन्यथा ऑर्डर रद्द होता है।\n\nकेवल ऑर्डर स्क्रीन पर उपलब्ध अवधि विकल्प चुनें। रद्द करने के दौरान भी निष्पादन हो सकता है। नया ऑर्डर देने से पहले स्थिति और होल्डिंग रीफ़्रेश करें।',
    sortOrder: 40,
  },
  {
    key: 'article.05',
    titleEn: 'Funding and withdrawals',
    bodyEn:
      'Use Add Funds to contact the in-app support team. Funds appear only after the finance team confirms and credits the account. Check the Funds Ledger for completed entries.\n\nSet a six-digit Withdrawal PIN in Profile. This is separate from your login password and is required when submitting a withdrawal. Add an approved bank account and check available funds. The minimum withdrawal is INR 100. Submitted funds are frozen during review; approval debits cash, while rejection releases the frozen amount. Keep the withdrawal order number for follow-up.',
    titleHi: 'जमा और निकासी',
    bodyHi:
      'राशि जोड़ने के लिए ऐप की सहायता टीम से संपर्क करें। वित्त टीम की पुष्टि और क्रेडिट के बाद ही राशि दिखाई देती है। पूरे हुए लेनदेन राशि के लेजर में देखें।\n\nप्रोफ़ाइल में छह अंकों का निकासी पिन सेट करें। यह लॉगिन पासवर्ड से अलग है और निकासी अनुरोध के लिए आवश्यक है। स्वीकृत बैंक खाता जोड़ें और उपलब्ध राशि जाँचें। न्यूनतम निकासी 100 रुपये है। समीक्षा के दौरान राशि रोक दी जाती है; स्वीकृति पर कटती है और अस्वीकृति पर मुक्त होती है। अनुरोध का ऑर्डर नंबर सुरक्षित रखें।',
    sortOrder: 50,
  },
  {
    key: 'article.06',
    titleEn: 'Holdings and returns',
    bodyEn:
      'Home Total Asset Value combines account cash and all stock holdings. Available funds and frozen margin are parts of account funds, not additional assets. Portfolio is limited to Institutional, OTC and IPO holdings; ordinary stocks remain in trading holdings.\n\nUnrealized profit or loss compares current valuation with acquisition cost. Realized profit or loss comes from completed sales. Period returns use recorded account profit observations, not deposits. History begins when reliable observations are available; insufficient history is shown explicitly. Missing quotes may use cost as a fallback valuation.',
    titleHi: 'होल्डिंग और रिटर्न',
    bodyHi:
      'होम पर कुल परिसंपत्ति मूल्य में खाते की नकदी और सभी शेयर होल्डिंग शामिल हैं। उपलब्ध राशि और रोका गया मार्जिन खाते की राशि के हिस्से हैं, अतिरिक्त परिसंपत्तियाँ नहीं। पोर्टफोलियो में केवल संस्थागत, ओटीसी और आईपीओ हैं; सामान्य शेयर ट्रेडिंग होल्डिंग में रहते हैं।\n\nअप्राप्त लाभ या हानि वर्तमान मूल्य और खरीद लागत का अंतर है। प्राप्त लाभ या हानि पूरी हुई बिक्री से आती है। अवधि का रिटर्न दर्ज किए गए लाभ के अवलोकनों पर आधारित है, जमा राशि पर नहीं। पर्याप्त विश्वसनीय इतिहास न होने पर यह स्पष्ट दिखाया जाता है। भाव न मिलने पर लागत को वैकल्पिक मूल्य माना जा सकता है।',
    sortOrder: 60,
  },
  {
    key: 'article.07',
    titleEn: 'Institutional, OTC and IPO',
    bodyEn:
      'Review each offer’s price, eligibility and terms before submitting. Institutional offers and OTC orders can require review. An application or pending order is not a settled holding.\n\nIPO applications may be pending, allocated or rejected. An allocation can create an outstanding payment obligation. Check the allocation notice, required payment and status before assuming shares are available to sell. Portfolio allocation includes settled positions, not pending applications. Availability and returns are never guaranteed.',
    titleHi: 'संस्थागत, ओटीसी और आईपीओ',
    bodyHi:
      'आवेदन से पहले हर प्रस्ताव की कीमत, पात्रता और शर्तें पढ़ें। संस्थागत प्रस्ताव और ओटीसी ऑर्डर की समीक्षा आवश्यक हो सकती है। आवेदन या लंबित ऑर्डर निपटान की गई होल्डिंग नहीं है।\n\nआईपीओ आवेदन लंबित, आवंटित या अस्वीकृत हो सकता है। आवंटन पर भुगतान बकाया हो सकता है। शेयर बेचने योग्य मानने से पहले आवंटन सूचना, भुगतान और स्थिति जाँचें। परिसंपत्ति आवंटन में निपटान की गई होल्डिंग आती है, लंबित आवेदन नहीं। उपलब्धता और रिटर्न की गारंटी नहीं है।',
    sortOrder: 70,
  },
  {
    key: 'article.08',
    titleEn: 'Risk and account security',
    bodyEn:
      'Investments can lose value. Concentration, liquidity, price gaps and operational delays can increase losses. Borrowed funds add repayment obligations. Read product terms and do not rely on past performance as a guarantee.\n\nNever share passwords or your Withdrawal PIN, including with someone claiming to be support. Change your login password from Change Password and your withdrawal password from Transaction PIN. Five failed PIN attempts temporarily lock PIN verification. If you suspect account misuse, contact in-app support promptly. This learning material is general education, not personalized investment advice.',
    titleHi: 'जोखिम और खाता सुरक्षा',
    bodyHi:
      'निवेश का मूल्य घट सकता है। एक ही निवेश में अधिक राशि, कम तरलता, कीमत में अंतर और परिचालन देरी से नुकसान बढ़ सकता है। उधार की राशि चुकाने की ज़िम्मेदारी होती है। उत्पाद की शर्तें पढ़ें और पिछले प्रदर्शन को गारंटी न मानें।\n\nपासवर्ड या निकासी पिन किसी से साझा न करें, सहायता कर्मचारी होने का दावा करने वाले से भी नहीं। लॉगिन पासवर्ड और निकासी पिन अलग पृष्ठों से बदलें। पाँच गलत पिन प्रयासों के बाद सत्यापन अस्थायी रूप से बंद हो जाता है। दुरुपयोग की आशंका पर ऐप सहायता से संपर्क करें। यह सामान्य शिक्षा है, व्यक्तिगत निवेश सलाह नहीं।',
    sortOrder: 80,
  },
];

export const APP_CONTENT_DEFAULTS: DefaultContent[] = [
  {
    module: AppContentModule.SUPPORT,
    key: 'tags',
    body: '入金咨询,提现问题,KYC,交易问题,账户问题,紧急,已跟进',
    locale: 'zh',
    sortOrder: 5,
  },
  {
    module: AppContentModule.LEGAL,
    key: 'privacy.document',
    title: 'Privacy Policy',
    body: JSON.stringify(privacyDocument),
    locale: 'en',
    sortOrder: 10,
  },
  {
    module: AppContentModule.LEGAL,
    key: 'terms.document',
    title: 'Terms of Service',
    body: JSON.stringify(termsDocument),
    locale: 'en',
    sortOrder: 20,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'company_name',
    body: 'India Trading App',
    locale: 'en',
    sortOrder: 10,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'legal_name',
    body: '',
    locale: 'en',
    sortOrder: 20,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'registered_address',
    body: '',
    locale: 'en',
    sortOrder: 30,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'grievance_contact',
    body: '',
    locale: 'en',
    sortOrder: 40,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'app_version',
    body: 'Version 1.0.0',
    locale: 'en',
    sortOrder: 50,
  },
  {
    module: AppContentModule.ABOUT,
    key: 'summary',
    body: 'Professional trading access for equities, institutional offers, OTC and IPOs. Complete legal entity, registered address and grievance contacts before public release.',
    locale: 'en',
    sortOrder: 60,
  },
  {
    module: AppContentModule.INSIGHTS,
    key: 'intro.title',
    body: 'Knowledge for informed investment decisions',
    locale: 'en',
    sortOrder: 1,
  },
  {
    module: AppContentModule.INSIGHTS,
    key: 'intro.body',
    body: 'Explore essential investment concepts, portfolio strategies, market perspectives and wealth-management principles designed to help investors make more informed financial decisions.',
    locale: 'en',
    sortOrder: 2,
  },
  ...insightArticles.flatMap((article) => [
    {
      module: AppContentModule.INSIGHTS,
      key: article.key,
      title: article.titleEn,
      body: article.bodyEn,
      locale: 'en',
      sortOrder: article.sortOrder,
    },
    {
      module: AppContentModule.INSIGHTS,
      key: article.key,
      title: article.titleHi,
      body: article.bodyHi,
      locale: 'hi',
      sortOrder: article.sortOrder,
    },
  ]),
];
