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
  role: "admin" | "merchant";
  phone?: string;
  governorate?: string;
  bank_percent?: number;
  platform_percent?: number;
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
  bank_amount?: number;
  platform_amount?: number;
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
  financed_amounts: number;
  merchants_count: number;
  due_this_month_amount?: number;
  due_this_month_count?: number;
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
