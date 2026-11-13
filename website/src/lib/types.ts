export type CustomerStatus =
  | "pending"
  | "active"
  | "inactive"
  | "completed"
  | "rejected";

export type AppUser = {
  id: string;
  username: string;
  full_name: string;
  role: "admin" | "merchant" | "investor";
  phone?: string;
  governorate?: string;
  bank_percent?: number;
  platform_percent?: number;
  investor_percent?: number;
  active?: boolean;
};

export type Payment = {
  id: string;
  amount: number;
  payment_date: string;
  note?: string | null;
  method?: string;
  installment_no?: number | null;
  created_at?: string;
};

export type Customer = {
  id: string;
  merchant_id?: string;
  merchant_name?: string | null;
  name: string;
  phone: string;
  governorate: string;
  mastercard_number?: string;
  national_id?: string;
  total_amount: number;
  months_count: number;
  registration_date: string;
  bank_percent?: number;
  platform_percent?: number;
  investor_percent?: number;
  bank_amount?: number;
  platform_amount?: number;
  investor_amount?: number;
  financed_amount?: number;
  monthly_payment: number;
  paid_amount: number;
  remaining_amount: number;
  remaining_months: number;
  payments_count?: number;
  first_due_date?: string | null;
  next_due_date?: string | null;
  status: CustomerStatus;
  whatsapp_url: string;
  payments?: Payment[];
};

export type DashboardStats = {
  total_customers: number;
  completed_count: number;
  remaining_count: number;
  late_count: number;
  pending_count: number;
  total_amounts: number;
  paid_amounts: number;
  remaining_amounts: number;
  bank_amounts: number;
  platform_amounts: number;
  investor_commission_amounts?: number;
  financed_amounts: number;
  merchants_count: number;
  due_this_month_amount?: number;
  due_this_month_count?: number;
  investors_count?: number;
  investments_count?: number;
  investor_principal_total?: number;
  investor_total_with_interest?: number;
  investor_paid_amount?: number;
  investor_remaining_amount?: number;
  investor_due_this_month_amount?: number;
};

export type PageResult<T> = {
  items: T[];
  total: number;
  page: number;
  page_size: number;
  pages: number;
};

export type LoginResponse = {
  access_token: string;
  user: AppUser;
};

export type DashboardResponse = {
  stats: DashboardStats;
  role: string;
};

export type Merchant = {
  id: string;
  username: string;
  full_name: string;
  phone: string;
  governorate: string;
  address: string;
  master_card: string;
  bank_percent: number;
  platform_percent: number;
  investor_percent?: number;
  active: boolean;
  customers_count: number;
  total_amounts: number;
  bank_amounts: number;
  platform_amounts: number;
  investor_amounts?: number;
  financed_amounts: number;
  paid_amounts: number;
  remaining_amounts: number;
  due_this_month_amount: number;
  due_this_month_count: number;
  due_confirmed_this_month?: boolean;
  due_carried_amount?: number;
  created_at: string;
};

export type InvestmentStatus = "active" | "completed" | "cancelled";

export type Investor = {
  id: string;
  username: string;
  full_name: string;
  phone: string;
  master_card: string;
  note?: string;
  role?: string;
  active: boolean;
  investments_count: number;
  principal_total: number;
  interest_total: number;
  total_with_interest: number;
  paid_amount: number;
  remaining_amount: number;
  due_this_month_amount: number;
  monthly_payout_total: number;
  created_at: string;
};

export type InvestorPayout = {
  id: string;
  investment_id: string;
  investor_id: string;
  amount: number;
  installment_no: number;
  due_date: string;
  paid: boolean;
  paid_at?: string | null;
  note?: string | null;
  created_at: string;
};

export type Investment = {
  id: string;
  investor_id: string;
  investor_name?: string | null;
  principal: number;
  interest_percent: number;
  interest_amount: number;
  total_with_interest: number;
  months_count: number;
  monthly_payout: number;
  start_date: string;
  first_due_date: string;
  status: InvestmentStatus;
  note?: string;
  paid_amount: number;
  remaining_amount: number;
  remaining_months: number;
  due_this_month_amount: number;
  payouts?: InvestorPayout[];
  created_at: string;
  updated_at?: string | null;
};
