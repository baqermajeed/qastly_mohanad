"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import { createInvestment } from "@/lib/api";
import { firstDueDate, formatDate, money, parseMoney } from "@/lib/format";

type Props = {
  open: boolean;
  investorId: string;
  investorName: string;
  onClose: () => void;
  onSaved: () => void;
};

export function AddInvestmentSheet({
  open,
  investorId,
  investorName,
  onClose,
  onSaved,
}: Props) {
  const [principal, setPrincipal] = useState("");
  const [interest, setInterest] = useState("10");
  const [months, setMonths] = useState("10");
  const [startDate, setStartDate] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setError(null);
    setPrincipal("");
    setInterest("10");
    setMonths("10");
    setNote("");
    const today = new Date();
    const yyyy = today.getFullYear();
    const mm = String(today.getMonth() + 1).padStart(2, "0");
    const dd = String(today.getDate()).padStart(2, "0");
    setStartDate(`${yyyy}-${mm}-${dd}`);
  }, [open]);

  const preview = useMemo(() => {
    const p = parseMoney(principal);
    const i = parseMoney(interest);
    const m = Number(months);
    if (p == null || i == null || !Number.isFinite(m) || m <= 0) return null;
    const interestAmount = (p * i) / 100;
    const total = p + interestAmount;
    return {
      interestAmount,
      total,
      monthly: total / m,
      firstDue: startDate
        ? firstDueDate(new Date(`${startDate}T00:00:00`))
        : firstDueDate(),
    };
  }, [principal, interest, months, startDate]);

  if (!open) return null;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    const p = parseMoney(principal);
    const i = parseMoney(interest);
    const m = Number(months);
    if (p == null || p <= 0) {
      setError("أدخل مبلغاً صالحاً");
      return;
    }
    if (i == null || i < 0 || i > 100) {
      setError("نسبة الفائدة غير صالحة");
      return;
    }
    if (!Number.isFinite(m) || m <= 0 || m > 120) {
      setError("عدد الأشهر بين 1 و 120");
      return;
    }

    setBusy(true);
    try {
      await createInvestment({
        investor_id: investorId,
        principal: p,
        interest_percent: i,
        months_count: m,
        start_date: startDate || undefined,
        note: note.trim(),
      });
      onSaved();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إنشاء العقد");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button
        type="button"
        className="sheet-backdrop is-open"
        style={{ zIndex: 70 }}
        aria-label="إغلاق"
        onClick={onClose}
      />
      <div
        className="center-dialog max-h-[88dvh] w-[min(calc(100%-28px),420px)] overflow-y-auto"
        style={{ zIndex: 71 }}
        role="dialog"
        aria-modal="true"
      >
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="text-base font-extrabold text-[var(--basic)]">
            عقد استثمار جديد
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="grid h-8 w-8 place-items-center rounded-xl bg-[#EAF6FB] text-sm font-bold"
          >
            ✕
          </button>
        </div>
        <p className="mb-3 text-[12px] font-semibold text-[var(--basic)]/55">
          للمستثمر: {investorName} — كل عقد مستقل عن العقود السابقة.
        </p>

        <form onSubmit={onSubmit} className="space-y-2.5">
          <input
            className="field"
            placeholder="المبلغ المستثمر (الكاش)"
            value={principal}
            onChange={(e) => setPrincipal(e.target.value)}
            inputMode="decimal"
            required
          />
          <div className="grid grid-cols-2 gap-2">
            <input
              className="field"
              placeholder="نسبة الفائدة %"
              value={interest}
              onChange={(e) => setInterest(e.target.value)}
              inputMode="decimal"
              required
            />
            <input
              className="field"
              placeholder="عدد الأشهر"
              value={months}
              onChange={(e) =>
                setMonths(e.target.value.replace(/\D/g, "").slice(0, 3))
              }
              inputMode="numeric"
              required
            />
          </div>
          <input
            className="field"
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            required
          />
          <textarea
            className="field min-h-[64px]"
            placeholder="ملاحظة (اختياري)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />

          {preview ? (
            <div className="rounded-2xl border border-[#D5E8F2] bg-[#F0F8FC] p-3 text-sm">
              <div className="mb-2 font-extrabold text-[var(--basic)]">
                معاينة الحساب
              </div>
              <div className="flex justify-between gap-2 py-0.5">
                <span className="text-[var(--basic)]/60">مبلغ الفائدة</span>
                <span className="font-bold">{money(preview.interestAmount)}</span>
              </div>
              <div className="flex justify-between gap-2 py-0.5">
                <span className="text-[var(--basic)]/60">بعد الفائدة</span>
                <span className="font-bold">{money(preview.total)}</span>
              </div>
              <div className="flex justify-between gap-2 py-0.5">
                <span className="text-[var(--basic)]/60">القسط الشهري</span>
                <span className="font-bold">{money(preview.monthly)}</span>
              </div>
              <div className="mt-1 text-[11px] font-semibold text-[var(--basic)]/55">
                أول قسط: {formatDate(preview.firstDue)}
              </div>
            </div>
          ) : null}

          {error ? (
            <div className="rounded-xl bg-[#FDECEC] px-3 py-2 text-sm font-bold text-[var(--late)]">
              {error}
            </div>
          ) : null}

          <div className="grid grid-cols-2 gap-2 pt-1">
            <button
              type="button"
              className="h-11 rounded-xl border border-[#D5E8F2] bg-white text-sm font-extrabold"
              onClick={onClose}
              disabled={busy}
            >
              إلغاء
            </button>
            <button type="submit" className="btn-primary h-11" disabled={busy}>
              {busy ? "جاري الإنشاء..." : "إنشاء العقد"}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
