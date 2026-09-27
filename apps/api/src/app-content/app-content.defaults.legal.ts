import { AppContentModule } from '../generated/prisma/enums';
import type { DefaultContent } from './app-content.defaults.types';

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

const riskDocument = {
  effective: 'Effective 16 September 2026  •  Version 1.0',
  sections: [
    {
      heading: '1. Capital and market risk',
      body: 'Investments can rise or fall in value and you may lose some or all of the capital committed. Market prices can change rapidly because of issuer, sector, economic, political, currency or broader market events. Past performance and displayed returns do not guarantee future results.',
    },
    {
      heading: '2. Volatility and liquidity risk',
      body: 'Some instruments may experience sharp price movements or limited trading interest. You may be unable to buy or sell the desired quantity at the displayed price, or at all. Low liquidity can increase price impact and the time required to complete or settle a transaction.',
    },
    {
      heading: '3. Execution and price risk',
      body: 'Quotes, charts and reference prices may be delayed, corrected or differ from the final transaction or settlement price. Submitting an instruction does not guarantee acceptance, execution, allocation or approval. Review the instrument, quantity, price basis, charges and total before confirming.',
    },
    {
      heading: '4. Product-specific risk',
      body: 'Institutional offers, IPOs and OTC products may involve restricted eligibility, uncertain allocation, limited liquidity, valuation uncertainty and additional review or settlement steps. OTC transactions remain pending until approved. Read the product details and do not treat an application or displayed position as a completed allocation or settlement.',
    },
    {
      heading: '5. Settlement, custody and counterparty risk',
      body: 'Transactions depend on the disclosed operator, banking, custody, allocation and settlement arrangements. Delays, rejection, reconciliation issues or counterparty failure may affect when cash or assets become available. Confirm the contracting entity, ownership record, settlement timing, cancellation rules and complaint route before transacting.',
    },
    {
      heading: '6. System and data risk',
      body: 'The application, networks, devices, market-data services, banking systems or other providers may be unavailable or contain delayed or inaccurate information. A pending screen, notification or balance display is not conclusive proof of execution or settlement. Check transaction records and contact support when information conflicts.',
    },
    {
      heading: '7. Borrowing and leverage risk',
      body: 'Borrowing money or using leverage to invest can magnify losses and may create repayment obligations even when an investment loses value. Do not borrow or commit funds needed for essential expenses, emergencies or near-term obligations.',
    },
    {
      heading: '8. Fraud and account-security risk',
      body: 'Fraudsters may impersonate staff or promise guaranteed returns. Never share passwords, OTPs or transaction keys, and use only verified in-app support channels. Report unauthorised activity promptly. India Trading does not guarantee returns or ask you to bypass the displayed transaction workflow.',
    },
    {
      heading: '9. Regulatory and tax risk',
      body: 'Laws, regulatory requirements, taxes, fees and product availability may change and can affect transactions or returns. Your tax and legal position depends on your circumstances. Obtain independent professional advice where needed.',
    },
    {
      heading: '10. Make an informed decision',
      body: 'This application provides information and transaction workflows; it does not provide personal investment, legal or tax advice unless expressly identified as such by an authorised professional. Consider your objectives, financial position, time horizon and ability to bear loss. Read all product disclosures and seek independent advice before acting if you do not understand the risks.',
    },
  ],
};

export const LEGAL_DEFAULTS: DefaultContent[] = [
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
    module: AppContentModule.LEGAL,
    key: 'risk.document',
    title: 'Risk Disclosure',
    body: JSON.stringify(riskDocument),
    locale: 'en',
    sortOrder: 30,
  },
];
