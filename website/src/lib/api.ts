import type {
  AppUser,
  Customer,
  CustomerStatus,
  DashboardResponse,
  Investment,
  InvestmentStatus,
  Investor,
  LoginResponse,
  Merchant,
  PageResult,
} from "./types";

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  "https://qasatly.compassaccuracy.com";

/** يصحّح remaining_months عندما API يرجع ceil خاطئ بسبب تقريب القسط. */
function normalizeCustomer(customer: Customer): Customer {
  if (customer.remaining_amount <= 0) {
    return { ...customer, remaining_months: 0 };
  }
  const paid = customer.payments_count ?? 0;
  const remaining = Math.max(0, customer.months_count - paid);
  return {
    ...customer,
    remaining_months: Math.min(remaining, customer.months_count),
  };
}

const TOKEN_KEY = "qasitli_auth_token";
const USER_KEY = "qasitli_auth_user";

export function getStoredToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function getStoredUser(): AppUser | null {
  if (typeof window === "undefined") return null;
  const raw = localStorage.getItem(USER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AppUser;
  } catch {
    return null;
  }
}

export function storeSession(token: string, user: AppUser) {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
}

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

function redirectToLogin() {
  if (typeof window === "undefined") return;
  clearSession();
  if (!window.location.pathname.startsWith("/login")) {
    window.location.replace("/login");
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const token = getStoredToken();
  const headers = new Headers(options.headers);
  headers.set("Content-Type", "application/json");
  if (token) headers.set("Authorization", `Bearer ${token}`);

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  const text = await res.text();
  let data: unknown = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }

  if (!res.ok) {
    const detail =
      typeof data === "object" &&
      data &&
      "detail" in data &&
      typeof (data as { detail: unknown }).detail === "string"
        ? (data as { detail: string }).detail
        : `خطأ في الاتصال بالخادم (${res.status})`;

    // جلسة منتهية / غير موجودة في السيرفر
    if (res.status === 401 && !path.includes("/auth/login")) {
      redirectToLogin();
    }

    throw new ApiError(detail, res.status);
  }

  return data as T;
}

export async function login(username: string, password: string) {
  const data = await request<LoginResponse>("/api/auth/login", {
    method: "POST",
    body: JSON.stringify({ username, password }),
  });
  storeSession(data.access_token, data.user);
  return data;
}

export async function logout() {
  try {
    await request("/api/auth/logout", { method: "POST" });
  } catch {
    // local logout always succeeds
  } finally {
    clearSession();
  }
}

export async function getDashboard(params?: { month?: string }) {
  const q = new URLSearchParams();
  if (params?.month) q.set("month", params.month);
  const suffix = q.toString() ? `?${q.toString()}` : "";
  return request<DashboardResponse>(`/api/dashboard${suffix}`);
}

export type CustomersQuery = {
  q?: string;
  status?: CustomerStatus;
  governorate?: string;
  merchant_id?: string;
  date_from?: string;
  date_to?: string;
  page?: number;
  page_size?: number;
  exclude_pending?: boolean;
};

export async function getCustomers(params: CustomersQuery = {}) {
  const query = new URLSearchParams();
  query.set("page", String(params.page ?? 1));
  query.set("page_size", String(params.page_size ?? 10));
  if (params.q?.trim()) query.set("q", params.q.trim());
  if (params.status) query.set("status", params.status);
  if (params.governorate) query.set("governorate", params.governorate);
  if (params.merchant_id) query.set("merchant_id", params.merchant_id);
  if (params.date_from) query.set("date_from", params.date_from);
  if (params.date_to) query.set("date_to", params.date_to);
  if (params.exclude_pending) query.set("exclude_pending", "true");
  const page = await request<PageResult<Customer>>(
    `/api/customers?${query.toString()}`,
  );
  return {
    ...page,
    items: page.items.map(normalizeCustomer),
  };
}

export async function createCustomer(payload: {
  name: string;
  phone: string;
  governorate: string;
  total_amount: number;
  months_count: number;
  registration_date?: string;
  mastercard_number?: string;
  national_id?: string;
}) {
  const customer = await request<Customer>("/api/customers", {
    method: "POST",
    body: JSON.stringify(payload),
  });
  return normalizeCustomer(customer);
}

export async function getCustomer(id: string) {
  const customer = await request<Customer>(`/api/customers/${id}`);
  return normalizeCustomer(customer);
}

export async function updateCustomer(
  id: string,
  payload: {
    name?: string;
    phone?: string;
    governorate?: string;
    mastercard_number?: string;
    national_id?: string;
    status?: CustomerStatus;
    confirm_password?: string;
  },
) {
  const customer = await request<Customer>(`/api/customers/${id}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
  return normalizeCustomer(customer);
}

export async function approveCustomer(id: string) {
  const customer = await request<Customer>(`/api/customers/${id}/approve`, {
    method: "POST",
    body: JSON.stringify({}),
  });
  return normalizeCustomer(customer);
}

export async function rejectCustomer(id: string) {
  const customer = await request<Customer>(`/api/customers/${id}/reject`, {
    method: "POST",
    body: JSON.stringify({}),
  });
  return normalizeCustomer(customer);
}

export type MerchantsQuery = {
  q?: string;
  governorate?: string;
  page?: number;
  page_size?: number;
};

export async function getMerchants(params: MerchantsQuery = {}) {
  const query = new URLSearchParams();
  query.set("page", String(params.page ?? 1));
  query.set("page_size", String(params.page_size ?? 10));
  if (params.q?.trim()) query.set("q", params.q.trim());
  if (params.governorate) query.set("governorate", params.governorate);
  return request<PageResult<Merchant>>(`/api/merchants?${query.toString()}`);
}

export async function createMerchant(payload: {
  username: string;
  password: string;
  full_name: string;
  phone: string;
  governorate: string;
  address: string;
  master_card: string;
  bank_percent: number;
  platform_percent: number;
  investor_percent?: number;
}) {
  return request<Merchant>("/api/merchants", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function getMerchant(id: string) {
  return request<Merchant>(`/api/merchants/${id}`);
}

export async function updateMerchant(
  id: string,
  payload: {
    full_name?: string;
    phone?: string;
    governorate?: string;
    address?: string;
    master_card?: string;
    password?: string;
    bank_percent?: number;
    platform_percent?: number;
    investor_percent?: number;
    active?: boolean;
  },
) {
  return request<Merchant>(`/api/merchants/${id}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}

export async function confirmMerchantDues(id: string, amount?: number) {
  return request<Merchant>(`/api/merchants/${id}/confirm-dues`, {
    method: "POST",
    body: JSON.stringify(amount != null ? { amount } : {}),
  });
}

export type InvestorsQuery = {
  q?: string;
  page?: number;
  page_size?: number;
};

export async function getInvestors(params: InvestorsQuery = {}) {
  const query = new URLSearchParams();
  query.set("page", String(params.page ?? 1));
  query.set("page_size", String(params.page_size ?? 10));
  if (params.q?.trim()) query.set("q", params.q.trim());
  return request<PageResult<Investor>>(`/api/investors?${query.toString()}`);
}

export async function getInvestor(id: string) {
  return request<Investor>(`/api/investors/${id}`);
}

export async function createInvestor(payload: {
  username: string;
  password: string;
  full_name: string;
  phone: string;
  master_card: string;
  note?: string;
}) {
  return request<Investor>("/api/investors", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function updateInvestor(
  id: string,
  payload: {
    full_name?: string;
    phone?: string;
    master_card?: string;
    password?: string;
    note?: string;
    active?: boolean;
  },
) {
  return request<Investor>(`/api/investors/${id}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}

export type InvestmentsQuery = {
  investor_id?: string;
  status?: InvestmentStatus;
  page?: number;
  page_size?: number;
};

export async function getInvestments(params: InvestmentsQuery = {}) {
  const query = new URLSearchParams();
  query.set("page", String(params.page ?? 1));
  query.set("page_size", String(params.page_size ?? 20));
  if (params.investor_id) query.set("investor_id", params.investor_id);
  if (params.status) query.set("status", params.status);
  return request<PageResult<Investment>>(
    `/api/investments?${query.toString()}`,
  );
}

export async function getInvestment(id: string) {
  return request<Investment>(`/api/investments/${id}`);
}

export async function createInvestment(payload: {
  investor_id: string;
  principal: number;
  interest_percent: number;
  months_count: number;
  start_date?: string;
  note?: string;
}) {
  return request<Investment>("/api/investments", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function confirmInvestmentPayouts(investmentId: string) {
  return request<Investment>(
    `/api/investments/${investmentId}/confirm-payouts`,
    {
      method: "POST",
      body: JSON.stringify({}),
    },
  );
}

export async function confirmPayout(payoutId: string) {
  return request<Investment>(`/api/investments/payouts/${payoutId}/confirm`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}
