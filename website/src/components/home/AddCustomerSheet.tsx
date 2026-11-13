"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { createCustomer, getStoredUser } from "@/lib/api";
import {
  firstDueDate,
  formatDate,
  formatDateTime,
  iraqiGovernorates,
  money,
  parseMoney,
} from "@/lib/format";

type Props = {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
};

function ReadonlyBox({ value }: { value: string }) {
  return (
    <div className="field flex items-center bg-[#F3FAFD] text-sm font-bold text-[var(--basic)]">
      {value}
    </div>
  );
}

export function AddCustomerSheet({ open, onClose, onCreated }: Props) {
  const user = getStoredUser();
  const bankPercent = user?.bank_percent ?? 0;
  const platformPercent = user?.platform_percent ?? 0;
  const investorPercent = user?.investor_percent ?? 0;

  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [governorate, setGovernorate] = useState("");
  const [totalAmount, setTotalAmount] = useState("");
  const [monthsCount, setMonthsCount] = useState("");
  const [mastercard, setMastercard] = useState("");
  const [nationalId, setNationalId] = useState("");
  const [notes, setNotes] = useState("");
  const [now, setNow] = useState(() => new Date());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    const timer = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(timer);
  }, [open]);

  const total = parseMoney(totalAmount);
  const months = Number.parseInt(monthsCount.trim(), 10);
  const bankAmount = total == null ? null : (total * bankPercent) / 100;
  const platformAmount = total == null ? null : (total * platformPercent) / 100;
  const investorAmount =
    total == null ? null : (total * investorPercent) / 100;
  const financed =
    total == null ||
    bankAmount == null ||
    platformAmount == null ||
    investorAmount == null
      ? null
      : total - bankAmount - platformAmount - investorAmount;
  const monthly =
    financed == null || !Number.isFinite(months) || months <= 0
      ? null
      : financed / months;
  const due = useMemo(() => firstDueDate(now), [now]);

  if (!open) return null;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);

    const cleanedName = name.trim().replace(/\s+/g, " ");
    if (cleanedName.length < 3) {
      setError("أدخل الاسم الثلاثي للزبون");
      return;
    }
    if (!/^\d{11}$/.test(phone.trim())) {
      setError("أدخل رقم هاتف عراقي صحيح (11 رقم)");
      return;
    }
    if (!governorate) {
      setError("اختر المحافظة");
      return;
    }
    if (total == null || total <= 0) {
      setError("أدخل مبلغاً صحيحاً");
      return;
    }
    if (!Number.isFinite(months) || months <= 0) {
      setError("أدخل عدد أشهر صحيح");
      return;
    }

    setBusy(true);
    try {
      await createCustomer({
        name: cleanedName,
        phone: phone.trim(),
        governorate,
        total_amount: total,
        months_count: months,
        registration_date: now.toISOString().slice(0, 10),
        mastercard_number: mastercard.trim() || undefined,
        national_id: nationalId.trim() || undefined,
      });
      setName("");
      setPhone("");
      setGovernorate("");
      setTotalAmount("");
      setMonthsCount("");
      setMastercard("");
      setNationalId("");
      setNotes("");
      onCreated();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إضافة الزبون");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button
        type="button"
        className="sheet-backdrop is-open"
        aria-label="إغلاق"
        onClick={onClose}
      />
      <div
        className="center-dialog max-h-[86dvh] w-[min(calc(100%-28px),400px)]"
        role="dialog"
        aria-modal="true"
      >
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="text-base font-extrabold text-[var(--basic)]">
            إضافة زبون جديد
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="grid h-8 w-8 place-items-center rounded-xl bg-[#EAF6FB] text-sm font-bold text-[var(--basic)]"
            aria-label="إغلاق"
          >
            ✕
          </button>
        </div>

        <form onSubmit={onSubmit} className="space-y-3">
          <section className="rounded-2xl bg-[#F7FBFD] p-3">
            <h4 className="mb-2 text-sm font-extrabold text-[var(--basic)]">
              معلومات الزبون
            </h4>
            <div className="space-y-2.5">
              <div>
                <label className="mb-1 block text-xs font-bold">
                  اسم الزبون <span className="text-[var(--late)]">*</span>
                </label>
                <input
                  className="field bg-white"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="أدخل الاسم الثلاثي للزبون"
                  required
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  رقم الهاتف <span className="text-[var(--late)]">*</span>
                </label>
                <input
                  className="field bg-white"
                  value={phone}
                  onChange={(e) =>
                    setPhone(e.target.value.replace(/\D/g, "").slice(0, 11))
                  }
                  placeholder="0770xxxxxxxx"
                  inputMode="numeric"
                  required
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  المحافظة <span className="text-[var(--late)]">*</span>
                </label>
                <select
                  className="field bg-white"
                  value={governorate}
                  onChange={(e) => setGovernorate(e.target.value)}
                  required
                >
                  <option value="">اختر المحافظة</option>
                  {iraqiGovernorates.map((g) => (
                    <option key={g} value={g}>
                      {g}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </section>

          <section className="rounded-2xl bg-[#F7FBFD] p-3">
            <h4 className="mb-2 text-sm font-extrabold text-[var(--basic)]">
              تفاصيل التقسيط
            </h4>
            <div className="grid grid-cols-2 gap-2.5">
              <div>
                <label className="mb-1 block text-xs font-bold">
                  المبلغ الكلي <span className="text-[var(--late)]">*</span>
                </label>
                <input
                  className="field bg-white"
                  value={totalAmount}
                  onChange={(e) => setTotalAmount(e.target.value)}
                  placeholder="أدخل المبلغ الكلي"
                  inputMode="decimal"
                  required
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  عدد أشهر التقسيط <span className="text-[var(--late)]">*</span>
                </label>
                <input
                  className="field bg-white"
                  value={monthsCount}
                  onChange={(e) =>
                    setMonthsCount(e.target.value.replace(/\D/g, ""))
                  }
                  placeholder="أدخل عدد الأشهر"
                  inputMode="numeric"
                  required
                />
              </div>
            </div>
            <div className="mt-2.5">
              <label className="mb-1 block text-xs font-bold">
                مبلغ الدفعة الشهرية
              </label>
              <ReadonlyBox
                value={monthly == null ? "0 د.ع" : `${money(monthly)} د.ع`}
              />
            </div>
          </section>

          <section className="rounded-2xl bg-[#F7FBFD] p-3">
            <h4 className="mb-2 text-sm font-extrabold text-[var(--basic)]">
              توزيع المبالغ
            </h4>
            <div className="space-y-2.5">
              <div>
                <label className="mb-1 block text-xs font-bold">
                  نسبة المصرف ({bankPercent}%)
                </label>
                <ReadonlyBox
                  value={
                    bankAmount == null ? "0 د.ع" : `${money(bankAmount)} د.ع`
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  نسبة المنصة ({platformPercent}%)
                </label>
                <ReadonlyBox
                  value={
                    platformAmount == null
                      ? "0 د.ع"
                      : `${money(platformAmount)} د.ع`
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  نسبة المستثمر ({investorPercent}%)
                </label>
                <ReadonlyBox
                  value={
                    investorAmount == null
                      ? "0 د.ع"
                      : `${money(investorAmount)} د.ع`
                  }
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  المبلغ بعد النسب
                </label>
                <ReadonlyBox
                  value={financed == null ? "0 د.ع" : `${money(financed)} د.ع`}
                />
              </div>
              <p className="text-[12px] font-bold text-[#1E88C8]">
                أول دفعة تُضاف يوم {formatDate(due)} (1 من الشهر التالي)
              </p>
            </div>
          </section>

          <section className="rounded-2xl bg-[#F7FBFD] p-3">
            <h4 className="mb-2 text-sm font-extrabold text-[var(--basic)]">
              معلومات إضافية
            </h4>
            <div className="space-y-2.5">
              <div>
                <label className="mb-1 block text-xs font-bold">
                  رقم الماستر كارد
                </label>
                <input
                  className="field bg-white"
                  value={mastercard}
                  onChange={(e) =>
                    setMastercard(e.target.value.replace(/\D/g, "").slice(0, 19))
                  }
                  placeholder="أدخل رقم الماستر كارد"
                  inputMode="numeric"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  رقم البطاقة الوطنية
                </label>
                <input
                  className="field bg-white"
                  value={nationalId}
                  onChange={(e) =>
                    setNationalId(e.target.value.replace(/\D/g, "").slice(0, 20))
                  }
                  placeholder="أدخل رقم البطاقة الوطنية"
                  inputMode="numeric"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  تاريخ ووقت التسجيل
                </label>
                <ReadonlyBox value={formatDateTime(now)} />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">ملاحظات</label>
                <input
                  className="field bg-white"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="أضف ملاحظات (اختياري)"
                />
              </div>
            </div>
          </section>

          {error ? (
            <p className="text-center text-sm font-bold text-[var(--late)]">
              {error}
            </p>
          ) : null}

          <div className="grid grid-cols-2 gap-2 pt-1">
            <button
              type="button"
              className="btn-filter w-full justify-center"
              onClick={onClose}
            >
              إلغاء
            </button>
            <button
              type="submit"
              className="btn-primary w-full whitespace-nowrap text-[13px]"
              disabled={busy}
            >
              {busy ? "جاري الإرسال..." : "إرسال طلب الخطة"}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
