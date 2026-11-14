"use client";

import { useEffect, useState } from "react";
import {
  confirmInvestorDues,
  getInvestments,
  getInvestor,
} from "@/lib/api";
import {
  computeLastDueDate,
  formatDateString,
  money,
} from "@/lib/format";
import type { Investment, Investor } from "@/lib/types";
import { AddInvestmentSheet } from "@/components/admin/AddInvestmentSheet";
import { AddInvestorSheet } from "@/components/admin/AddInvestorSheet";

type Props = {
  investorId: string | null;
  open: boolean;
  onClose: () => void;
  onUpdated?: () => void;
  isAdmin?: boolean;
  initialInvestmentId?: string | null;
};

function statusLabel(status: string) {
  if (status === "completed") return "مكتمل";
  if (status === "cancelled") return "ملغى";
  return "نشط";
}

function statusColor(status: string) {
  if (status === "completed") return "#0E8A61";
  if (status === "cancelled") return "#C0392B";
  return "#2E86C1";
}

export function InvestorDetailSheet({
  investorId,
  open,
  onClose,
  onUpdated,
  isAdmin = true,
}: Props) {
  const [investor, setInvestor] = useState<Investor | null>(null);
  const [investments, setInvestments] = useState<Investment[]>([]);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);
  const [addInvestmentOpen, setAddInvestmentOpen] = useState(false);
  const [settleOpen, setSettleOpen] = useState(false);
  const [settleAmount, setSettleAmount] = useState("");

  async function load(id: string) {
    setLoading(true);
    setError(null);
    try {
      const [inv, list] = await Promise.all([
        getInvestor(id),
        getInvestments({ investor_id: id, page: 1, page_size: 50 }),
      ]);
      setInvestor(inv);
      setInvestments(list.items);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل البيانات");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!open || !investorId) return;
    void load(investorId);
  }, [open, investorId]);

  if (!open) return null;

  const due = investor?.due_this_month_amount ?? 0;
  const initial = (investor?.full_name?.trim()?.[0] || "م").toString();

  async function onSettle() {
    if (!investorId || !investor) return;
    const raw = settleAmount.trim().replace(/,/g, "");
    const value = Number(raw);
    if (!Number.isFinite(value) || value <= 0) return;
    if (value > due + 0.01) {
      setError(`مبلغ التسديد أكبر من المستحقات (${money(due)})`);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const updated = await confirmInvestorDues(investorId, value);
      setInvestor(updated);
      setSettleOpen(false);
      await load(investorId);
      onUpdated?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تسديد المستحقات");
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
        className="center-dialog max-h-[92dvh] w-[min(calc(100%-24px),520px)] overflow-y-auto bg-[#F7FBFD]"
        role="dialog"
        aria-modal="true"
      >
        <div className="-mx-1 mb-3 flex items-center gap-3 border-b border-[#D5E8F2] bg-white px-1 pb-3">
          <div className="grid h-10 w-10 shrink-0 place-items-center rounded-[14px] bg-gradient-to-bl from-[#064E6A] to-[#069BAF] text-base font-extrabold text-white">
            {initial}
          </div>
          <div className="min-w-0 flex-1">
            <h3 className="truncate text-[15px] font-extrabold text-[var(--basic)]">
              {investor?.full_name || "تفاصيل المستثمر"}
            </h3>
            <div className="mt-0.5 truncate text-[12px] font-semibold text-[var(--basic)]/55">
              {investor
                ? `${investor.phone || `@${investor.username}`}`
                : "—"}
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="grid h-8 w-8 place-items-center rounded-xl bg-[#EAF6FB] text-sm font-bold"
          >
            ✕
          </button>
        </div>

        {isAdmin ? (
          <div className="mb-3 grid grid-cols-2 gap-2">
            <button
              type="button"
              className="h-10 rounded-xl border border-[#D5E8F2] bg-white text-sm font-extrabold"
              onClick={() => setEditOpen(true)}
            >
              تعديل
            </button>
            <button
              type="button"
              className="btn-primary h-10"
              onClick={() => setAddInvestmentOpen(true)}
            >
              + عقد استثمار
            </button>
          </div>
        ) : null}

        {loading ? (
          <div className="py-10 text-center text-sm font-bold text-[var(--soft)]">
            جاري التحميل...
          </div>
        ) : error ? (
          <div className="rounded-2xl bg-[#FDECEC] p-4 text-center text-sm font-bold text-[var(--late)]">
            {error}
          </div>
        ) : !investor ? (
          <div className="rounded-2xl bg-white p-6 text-center text-sm font-bold text-[var(--basic)]/50">
            لا توجد بيانات
          </div>
        ) : (
          <>
            <h4 className="mb-2 text-sm font-extrabold text-[var(--basic)]">
              إحصائيات عامة
            </h4>
            <div className="mb-3 grid grid-cols-3 gap-2">
              {(
                [
                  ["عدد العقود", `${investor.investments_count}`],
                  ["أصل الرصيد", money(investor.principal_total)],
                  ["بعد الفائدة", money(investor.total_with_interest)],
                  ["المستلم", money(investor.paid_amount)],
                  ["المتبقي", money(investor.remaining_amount)],
                  ["القسط الشهري", money(investor.monthly_payout_total)],
                ] as const
              ).map(([label, value]) => (
                <div
                  key={label}
                  className="rounded-[14px] border border-[#D5E8F2] bg-white px-2 py-2.5 text-center"
                >
                  <div className="truncate text-[10px] font-bold text-[var(--basic)]/50">
                    {label}
                  </div>
                  <div className="mt-1 truncate text-[13px] font-extrabold text-[var(--basic)]">
                    {value}
                  </div>
                </div>
              ))}
            </div>

            <div className="mb-3 rounded-[16px] bg-gradient-to-bl from-[#064E6A] to-[#069BAF] p-4 text-white">
              <div className="text-[12px] font-semibold text-white/80">
                مستحقاته هذا الشهر
              </div>
              <div className="mt-1 text-[24px] font-extrabold leading-none">
                {money(due)}
              </div>
            </div>

            {isAdmin ? (
              <button
                type="button"
                className="mb-4 h-11 w-full rounded-xl bg-[#0E8A61] text-[14px] font-extrabold text-white disabled:opacity-50"
                disabled={busy || due <= 0.01}
                onClick={() => {
                  setSettleAmount(
                    due === Math.round(due) ? String(due) : due.toFixed(2),
                  );
                  setSettleOpen(true);
                }}
              >
                {due <= 0.01 ? "لا مستحقات حالياً" : "تسديد المستحقات"}
              </button>
            ) : null}

            <div className="mb-2 flex items-center justify-between gap-2">
              <h5 className="text-[15px] font-extrabold text-[var(--basic)]">
                العقود الاستثمارية
              </h5>
              <span className="rounded-full border border-[#D5E8F2] bg-white px-2.5 py-1 text-[11px] font-extrabold text-[var(--soft)]">
                {investments.length}
              </span>
            </div>

            {investments.length === 0 ? (
              <div className="rounded-2xl border border-[#D5E8F2] bg-white p-6 text-center text-sm font-bold text-[var(--basic)]/50">
                لا توجد عقود بعد
              </div>
            ) : (
              <div className="space-y-2">
                {investments.map((item, index) => {
                  const color = statusColor(item.status);
                  const last = computeLastDueDate(
                    item.first_due_date,
                    item.months_count,
                  );
                  return (
                    <article
                      key={item.id}
                      className="rounded-2xl border border-[#D5E8F2] bg-white p-3"
                    >
                      <div className="mb-2 flex items-start justify-between gap-2">
                        <div className="flex items-center gap-2">
                          <div className="grid h-8 w-8 place-items-center rounded-full bg-[#E3F4FB] text-[12px] font-extrabold text-[var(--soft)]">
                            {String(index + 1).padStart(2, "0")}
                          </div>
                          <div>
                            <div className="text-[15px] font-extrabold">
                              {money(item.principal)}
                            </div>
                            <div className="text-[11px] font-bold text-[var(--basic)]/55">
                              فائدة {item.interest_percent}%
                            </div>
                          </div>
                        </div>
                        <span
                          className="rounded-full px-2.5 py-1 text-[11px] font-extrabold"
                          style={{ color, background: `${color}1F` }}
                        >
                          {statusLabel(item.status)}
                        </span>
                      </div>
                      <div className="grid grid-cols-3 gap-2 rounded-xl bg-[#F7FBFD] px-2 py-2.5 text-center">
                        <div>
                          <div className="text-[10px] font-bold text-[var(--basic)]/50">
                            بعد الفائدة
                          </div>
                          <div className="text-[12px] font-extrabold">
                            {money(item.total_with_interest)}
                          </div>
                        </div>
                        <div>
                          <div className="text-[10px] font-bold text-[var(--basic)]/50">
                            القسط
                          </div>
                          <div className="text-[12px] font-extrabold">
                            {money(item.monthly_payout)}
                          </div>
                        </div>
                        <div>
                          <div className="text-[10px] font-bold text-[var(--basic)]/50">
                            المتبقي
                          </div>
                          <div className="text-[12px] font-extrabold text-[#C38508]">
                            {money(item.remaining_amount)}
                          </div>
                        </div>
                      </div>
                      <div className="mt-2 text-[11px] font-semibold text-[var(--basic)]/50">
                        أول قسط {formatDateString(item.first_due_date)} · آخر قسط{" "}
                        {formatDateString(last)} · {item.remaining_months}/
                        {item.months_count} شهر
                      </div>
                    </article>
                  );
                })}
              </div>
            )}
          </>
        )}
      </div>

      {settleOpen ? (
        <>
          <button
            type="button"
            className="sheet-backdrop is-open"
            aria-label="إغلاق"
            onClick={() => setSettleOpen(false)}
          />
          <div className="center-dialog w-[min(calc(100%-24px),400px)]" role="dialog">
            <h3 className="mb-2 text-base font-extrabold">تسديد مستحقات المستثمر</h3>
            <p className="mb-3 text-sm font-semibold text-[var(--basic)]/70">
              مستحقات هذا الشهر: {money(due)} د.ع — يمكنك التسديد كاملاً أو جزئياً.
            </p>
            <label className="mb-1 block text-xs font-bold">مبلغ التسديد</label>
            <input
              className="field mb-3"
              value={settleAmount}
              onChange={(e) => setSettleAmount(e.target.value)}
              inputMode="decimal"
            />
            <div className="grid grid-cols-2 gap-2">
              <button
                type="button"
                className="h-10 rounded-xl border border-[#D5E8F2] bg-white font-extrabold"
                onClick={() => setSettleOpen(false)}
              >
                إلغاء
              </button>
              <button
                type="button"
                className="h-10 rounded-xl bg-[#0E8A61] font-extrabold text-white disabled:opacity-60"
                disabled={busy}
                onClick={() => void onSettle()}
              >
                تأكيد التسديد
              </button>
            </div>
          </div>
        </>
      ) : null}

      {isAdmin && investor ? (
        <>
          <AddInvestorSheet
            open={editOpen}
            investor={investor}
            onClose={() => setEditOpen(false)}
            onSaved={() => {
              if (investorId) void load(investorId);
              onUpdated?.();
            }}
          />
          <AddInvestmentSheet
            open={addInvestmentOpen}
            investorId={investor.id}
            investorName={investor.full_name}
            onClose={() => setAddInvestmentOpen(false)}
            onSaved={() => {
              if (investorId) void load(investorId);
              onUpdated?.();
            }}
          />
        </>
      ) : null}
    </>
  );
}
