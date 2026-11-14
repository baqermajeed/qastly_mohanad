export function money(value: number): string {
  return new Intl.NumberFormat("en-US", {
    maximumFractionDigits: 2,
  }).format(value);
}

export function parseMoney(value: string): number | null {
  const cleaned = value.replace(/,/g, "").trim();
  if (!cleaned) return null;
  const n = Number(cleaned);
  return Number.isFinite(n) ? n : null;
}

export function firstDueDate(from = new Date()): Date {
  return new Date(from.getFullYear(), from.getMonth() + 1, 1);
}

export function formatDateTime(value: Date): string {
  const dd = String(value.getDate()).padStart(2, "0");
  const mm = String(value.getMonth() + 1).padStart(2, "0");
  const yyyy = value.getFullYear();
  const hh = String(value.getHours()).padStart(2, "0");
  const mi = String(value.getMinutes()).padStart(2, "0");
  const ss = String(value.getSeconds()).padStart(2, "0");
  return `${dd}/${mm}/${yyyy}  ${hh}:${mi}:${ss}`;
}

export function formatDate(value: Date): string {
  const dd = String(value.getDate()).padStart(2, "0");
  const mm = String(value.getMonth() + 1).padStart(2, "0");
  const yyyy = value.getFullYear();
  return `${dd}/${mm}/${yyyy}`;
}

export function formatDateString(value?: string | null): string {
  if (!value) return "—";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return formatDate(d);
}

/** تاريخ القسط الأخير الثابت في جدول الخطة. */
export function computeLastDueDate(
  firstDue?: string | null,
  monthsCount?: number | null,
): string | null {
  if (!firstDue || !monthsCount || monthsCount <= 0) return null;
  const start = new Date(firstDue);
  if (Number.isNaN(start.getTime())) return null;
  const index = start.getUTCMonth() + (monthsCount - 1);
  const year = start.getUTCFullYear() + Math.floor(index / 12);
  const month = index % 12;
  return `${year}-${String(month + 1).padStart(2, "0")}-01`;
}

export function paymentMethodLabel(method?: string): string {
  switch (method) {
    case "card":
      return "بطاقة";
    case "cash":
      return "نقداً";
    case "auto":
    default:
      return "نظام";
  }
}

/** يزيل كلمة «تلقائي» من الملاحظات القديمة المعروضة. */
export function cleanPaymentNote(note?: string | null): string {
  if (!note?.trim()) return "—";
  return note
    .replace(/دفعة شهرية تلقائية/g, "دفعة شهرية")
    .replace(/\s*تلقائية\s*/g, " ")
    .replace(/\s*تلقائي\s*/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

export function statusLabel(status: string): string {
  switch (status) {
    case "pending":
      return "بانتظار الموافقة";
    case "rejected":
      return "مرفوضة";
    case "inactive":
      return "غير نشطة";
    case "completed":
      return "مكتملة";
    case "active":
    default:
      return "نشطة";
  }
}

export const iraqiGovernorates = [
  "بغداد",
  "البصرة",
  "نينوى",
  "أربيل",
  "السليمانية",
  "دهوك",
  "كركوك",
  "الأنبار",
  "ديالى",
  "صلاح الدين",
  "بابل",
  "كربلاء",
  "النجف",
  "واسط",
  "ميسان",
  "ذي قار",
  "المثنى",
  "القادسية",
] as const;
