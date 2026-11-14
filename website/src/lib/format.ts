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
  // Prefer calendar date part to avoid timezone day-shift vs Flutter.
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (m) return `${m[3]}/${m[2]}/${m[1]}`;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return formatDate(d);
}

/** yyyy-MM-dd — مطابق formatDate في Flutter لجدول العقود. */
export function formatIsoDate(value?: string | null): string {
  if (!value) return "—";
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  if (m) return `${m[1]}-${m[2]}-${m[3]}`;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
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

export function installmentAmount(params: {
  financedAmount: number;
  monthsCount: number;
  monthlyPayment: number;
  installmentNo: number;
}): number {
  const { financedAmount, monthsCount, monthlyPayment, installmentNo } =
    params;
  if (installmentNo < monthsCount) {
    return Number(monthlyPayment.toFixed(2));
  }
  return Number(
    (financedAmount - monthlyPayment * (monthsCount - 1)).toFixed(2),
  );
}

/** مبلغ القسط المستحق في شهر معيّن حسب جدول العقد. */
export function installmentDueInMonth(params: {
  firstDue: string;
  monthsCount: number;
  monthlyPayment: number;
  financedAmount: number;
  month: Date;
}): number {
  const {
    firstDue,
    monthsCount,
    monthlyPayment,
    financedAmount,
    month,
  } = params;
  if (monthsCount <= 0) return 0;
  const start = new Date(firstDue);
  if (Number.isNaN(start.getTime())) return 0;
  const monthsDiff =
    (month.getUTCFullYear() - start.getUTCFullYear()) * 12 +
    (month.getUTCMonth() - start.getUTCMonth());
  if (monthsDiff < 0 || monthsDiff >= monthsCount) return 0;
  return installmentAmount({
    financedAmount,
    monthsCount,
    monthlyPayment,
    installmentNo: monthsDiff + 1,
  });
}

export function addMonthsIso(firstDue: string, monthsOffset: number): string {
  const start = new Date(firstDue);
  const index = start.getUTCMonth() + monthsOffset;
  const year = start.getUTCFullYear() + Math.floor(index / 12);
  const month = index % 12;
  return `${year}-${String(month + 1).padStart(2, "0")}-01`;
}

/** جدول كامل لكل أشهر العقد (مستلم / غير مستلم). */
export function buildInvestmentSchedule(inv: {
  months_count: number;
  monthly_payout: number;
  total_with_interest: number;
  first_due_date: string;
  payouts?: Array<{
    id: string;
    installment_no: number;
    due_date: string;
    amount: number;
    paid: boolean;
  }>;
}) {
  const byNo = new Map(
    (inv.payouts ?? []).map((p) => [p.installment_no, p] as const),
  );
  const months = inv.months_count;
  const monthly = inv.monthly_payout;
  const total = inv.total_with_interest;
  return Array.from({ length: months }, (_, i) => {
    const no = i + 1;
    const existing = byNo.get(no);
    const amount =
      no < months
        ? monthly
        : Number((total - monthly * (months - 1)).toFixed(2));
    return {
      installment_no: no,
      due_date: existing?.due_date ?? addMonthsIso(inv.first_due_date, i),
      amount: existing?.amount ?? amount,
      paid: existing?.paid ?? false,
      payout_id: existing?.id ?? null,
    };
  });
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
