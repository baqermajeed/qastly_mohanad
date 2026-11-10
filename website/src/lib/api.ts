import type {
  AppUser,
  Customer,
  CustomerStatus,
  DashboardResponse,
  LoginResponse,
  PageResult,
} from "./types";

const API_BASE =
  process.env.NEXT_PUBLIC_API_BASE_URL ??
  "https://qasatly.compassaccuracy.com";

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
    throw new Error(detail);
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

export async function getDashboard() {
  return request<DashboardResponse>("/api/dashboard");
}

export type CustomersQuery = {
  q?: string;
  status?: CustomerStatus;
  governorate?: string;
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
  if (params.date_from) query.set("date_from", params.date_from);
  if (params.date_to) query.set("date_to", params.date_to);
  if (params.exclude_pending) query.set("exclude_pending", "true");
  return request<PageResult<Customer>>(`/api/customers?${query.toString()}`);
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
  return request<Customer>("/api/customers", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export async function getCustomer(id: string) {
  return request<Customer>(`/api/customers/${id}`);
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
  return request<Customer>(`/api/customers/${id}`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  });
}
