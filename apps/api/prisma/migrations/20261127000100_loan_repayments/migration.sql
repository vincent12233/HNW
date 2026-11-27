CREATE TABLE "loan_repayments" (
  "id" TEXT NOT NULL,
  "loanId" TEXT NOT NULL,
  "requestId" TEXT NOT NULL,
  "amount" DECIMAL(18,2) NOT NULL CHECK ("amount" > 0),
  "note" TEXT,
  "actorId" TEXT NOT NULL,
  "response" JSONB NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "loan_repayments_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "loan_repayments_loanId_fkey" FOREIGN KEY ("loanId") REFERENCES "loan_applications"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE UNIQUE INDEX "loan_repayments_loanId_requestId_key" ON "loan_repayments"("loanId", "requestId");
