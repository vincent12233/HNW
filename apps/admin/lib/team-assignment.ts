export type AssignmentStaff = {
  id: string;
  fullName: string;
  role: string;
  status: string;
  employeeNo: string | null;
  isActive?: boolean | null;
  currentManagerId?: string | null;
  clientCount?: number;
  vipClientCount?: number;
  businessCount?: number;
  businesses?: AssignmentBusiness[];
};

export type AssignmentBusiness = AssignmentStaff & {
  clientCount: number;
  vipClientCount: number;
  currentManagerId: string | null;
};

export type AssignmentListResponse = {
  managers: AssignmentStaff[];
  unassigned: AssignmentBusiness[];
  managerOptions: AssignmentStaff[];
  totals: {
    managerCount: number;
    businessCount: number;
    unassignedCount: number;
    clientCount: number;
  };
};

export type AssignmentPreview = {
  business: AssignmentStaff;
  currentManager: AssignmentStaff | null;
  newManager: AssignmentStaff;
  clientCount: number;
  vipClientCount: number;
  warnings: string[];
};

export type AssignmentHistoryRow = {
  id: string;
  businessUserId: string;
  businessName: string;
  businessEmployeeNo: string | null;
  previousManagerId: string | null;
  previousManagerName: string | null;
  previousManagerEmployeeNo: string | null;
  newManagerId: string | null;
  newManagerName: string | null;
  newManagerEmployeeNo: string | null;
  reason: string;
  changedByName: string;
  clientCountAtChange: number;
  createdAt: string;
};

export function newAssignmentIdempotencyKey() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `assign-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
}
