"use client";

import { useEffect, useState } from "react";
import {
  confirmInvestmentPayouts,
  getInvestment,
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

export function InvestorDetailSheet({
  investorId,
  open,
  onClose,
  onUpdated,
  isAdmin = true,
  initialInvestmentId = null,
}: Props) {
  const [investor, setInvestor] = useState<Investor | null>(null);
  const [investments, setInvestments] = useState<Investment[]>([]);
  const [selected, setSelected] = useState<Investment | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);
  const [addInvestmentOpen, setAddInvestmentOpen] = useState(false);

  async function load(id: string, keepSelectedId?: string | null) {
    setLoading(true);
    setError(null);
    try {
      const [inv, list] = await Promise.all([
        getInvestor(id),
        getInvestments({ investor_id: id, page: 1, page_size: 50 }),
      ]);
      setInvestor(inv);
      setInvestments(list.items);
      const selectedId =
        keepSelectedId ||
        initialInvestmentId ||
        selected?.id ||
        list.items[0]?.id ||
        null;
      if (selectedId) {
        try {
          setSelected(await getInvestment(selectedId));
        } catch {
          setSelected(list.items.find((i) => i.id === selectedId) ?? null);
        }
      } else {
        setSelected(null);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل البيانات");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!open || !investorId) return;
    void load(investorId, initialInvestmentId);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, investorId, initialInvestmentId]);

  if (!open) return null;

  async function openInvestment(item: Investment) {
    setBusy(true);
    try {
      setSelected(await getInvestment(item.id));
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر فتح العقد");
    } finally {
      setBusy(false);
    }
  }

  async function onConfirmAll() {
    if (!selected) return;
    setBusy(true);
    try {
      const updated = await confirmInvestmentPayouts(selected.id);
      setSelected(updated);
      if (investorId) await load(investorId, updated.id);
      onUpdated?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تأكيد الصرف");
    } finally {
      setBusy(false);
    }
  }

  const unpaid = selected?.payouts?.filter((p) => !p.paid) ?? [];
  const initial =
    (investor?.full_name?.trim()?.[0] || "م").toString();
  const lastDue = selected
    ? computeLastDueDate(selected.first_due_date, selected.months_count)
    : null;

  return (
    <>
      <button
        type="button"
        className="sheet-backdrop is-open"
        aria-label="إغلاق"
        onClick={onClose}
      />
      <div
        className="center-dialog max-h-[92dvh] w-[min(calc(100%-24px),440px)] overflow-y-auto bg-[#F7FBFD]"
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
              {investor?.master_card
                ? ` · ماستر ${investor.master_card}`
                : ""}
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
        ) : !selected ? (
          <div className="rounded-2xl bg-white p-6 text-center text-sm font-bold text-[var(--basic)]/50">
            لا يوجد عقد لعرضه
          </div>
        ) : (
          <>
            {isAdmin && investments.length > 1 ? (
              <div className="mb-3">
                <label className="mb-1 block text-xs font-bold">العقد</label>
                <select
                  className="field"
                  value={selected.id}
                  disabled={busy}
                  onChange={(e) => {
                    const item = investments.find((i) => i.id === e.target.value);
                    if (item) void openInvestment(item);
                  }}
                >
                  {investments.map((item) => (
                    <option key={item.id} value={item.id}>
                      {money(item.principal)} · {item.months_count} شهر
                    </option>
                  ))}
                </select>
              </div>
            ) : null}

            <div className="mb-2 flex items-center justify-between gap-2">
              <h4 className="text-sm font-extrabold text-[var(--basic)]">
                معلومات وإحصائيات العقد
              </h4>
              {isAdmin && unpaid.length > 0 ? (
                <button
                  type="button"
                  className="rounded-xl bg-[var(--soft)] px-3 py-1.5 text-[11px] font-extrabold text-white disabled:opacity-60"
                  disabled={busy}
                  onClick={() => void onConfirmAll()}
                >
                  تأكيد المستحق
                </button>
              ) : null}
            </div>

            <div className="mb-3 grid grid-cols-3 gap-2">
              {(
                [
                  ["القسط الشهري", money(selected.monthly_payout)],
                  ["عدد الأشهر", `${selected.months_count}`],
                  ["أشهر متبقية", `${selected.remaining_months}`],
                  ["المستلم", money(selected.paid_amount)],
                  ["المتبقي", money(selected.remaining_amount)],
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

            <div className="grid grid-cols-2 gap-2">
              <div className="flex items-center gap-2.5 rounded-[14px] border border-[#D5E8F2] bg-white px-3 py-3">
                <div className="grid h-8 w-8 place-items-center rounded-[10px] bg-[#E8F5FC] text-[var(--soft)]">
                  ▶
                </div>
                <div className="min-w-0">
                  <div className="text-[10px] font-bold text-[var(--basic)]/50">
                    أول دفعة
                  </div>
                  <div className="text-[13px] font-extrabold">
                    {formatDateString(selected.first_due_date)}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2.5 rounded-[14px] border border-[#D5E8F2] bg-white px-3 py-3">
                <div className="grid h-8 w-8 place-items-center rounded-[10px] bg-[#E8F5FC] text-[var(--soft)]">
                  ⚑
                </div>
                <div className="min-w-0">
                  <div className="text-[10px] font-bold text-[var(--basic)]/50">
                    آخر دفعة
                  </div>
                  <div className="text-[13px] font-extrabold">
                    {formatDateString(lastDue)}
                  </div>
                </div>
              </div>
            </div>
          </>
        )}
      </div>

      {isAdmin && investor ? (
        <>
          <AddInvestorSheet
            open={editOpen}
            investor={investor}
            onClose={() => setEditOpen(false)}
            onSaved={() => {
              if (investorId) void load(investorId, selected?.id);
              onUpdated?.();
            }}
          />
          <AddInvestmentSheet
            open={addInvestmentOpen}
            investorId={investor.id}
            investorName={investor.full_name}
            onClose={() => setAddInvestmentOpen(false)}
            onSaved={() => {
              if (investorId) void load(investorId, selected?.id);
              onUpdated?.();
            }}
          />
        </>
      ) : null}
    </>
  );
}
