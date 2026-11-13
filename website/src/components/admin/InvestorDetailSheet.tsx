"use client";

import { useEffect, useState } from "react";
import {
  confirmInvestmentPayouts,
  confirmPayout,
  getInvestment,
  getInvestments,
  getInvestor,
} from "@/lib/api";
import { formatDateString, money } from "@/lib/format";
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
      const selectedId = keepSelectedId || initialInvestmentId || selected?.id;
      if (selectedId) {
        try {
          setSelected(await getInvestment(selectedId));
        } catch {
          setSelected(null);
        }
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

  async function onConfirmOne(payoutId: string) {
    setBusy(true);
    try {
      const updated = await confirmPayout(payoutId);
      setSelected(updated);
      if (investorId) await load(investorId, updated.id);
      onUpdated?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تأكيد القسط");
    } finally {
      setBusy(false);
    }
  }

  const unpaid = selected?.payouts?.filter((p) => !p.paid) ?? [];

  return (
    <>
      <button
        type="button"
        className="sheet-backdrop is-open"
        aria-label="إغلاق"
        onClick={onClose}
      />
      <div
        className="center-dialog max-h-[92dvh] w-[min(calc(100%-16px),560px)] overflow-y-auto"
        role="dialog"
        aria-modal="true"
      >
        <div className="mb-3 flex items-start justify-between gap-2">
          <div className="min-w-0">
            <h3 className="truncate text-base font-extrabold text-[var(--basic)]">
              {investor?.full_name || "تفاصيل المستثمر"}
            </h3>
            <div className="mt-1 text-[12px] font-semibold text-[var(--basic)]/55">
              {investor
                ? `@${investor.username} · ${investor.phone || "—"}`
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
        ) : (
          <>
            <div className="mb-3 grid grid-cols-2 gap-2">
              {(
                [
                  ["أصل الرصيد", money(investor?.principal_total ?? 0)],
                  ["بعد الفائدة", money(investor?.total_with_interest ?? 0)],
                  ["المستلم", money(investor?.paid_amount ?? 0)],
                  ["المتبقي", money(investor?.remaining_amount ?? 0)],
                ] as const
              ).map(([label, value]) => (
                <div
                  key={label}
                  className="rounded-2xl bg-[#F3FAFD] px-3 py-2.5"
                >
                  <div className="text-[11px] font-bold text-[var(--basic)]/55">
                    {label}
                  </div>
                  <div className="mt-1 text-[14px] font-extrabold text-[var(--basic)]">
                    {value}
                  </div>
                </div>
              ))}
            </div>

            <h4 className="mb-2 text-sm font-extrabold text-[var(--basic)]">
              العقود ({investments.length})
            </h4>
            <div className="mb-3 space-y-2">
              {investments.length === 0 ? (
                <div className="rounded-2xl bg-[#F7FBFD] p-5 text-center text-sm font-bold text-[var(--basic)]/50">
                  لا توجد عقود بعد
                </div>
              ) : (
                investments.map((item) => {
                  const selectedRow = selected?.id === item.id;
                  const color = statusColor(item.status);
                  return (
                    <button
                      key={item.id}
                      type="button"
                      className={`w-full rounded-2xl border px-3 py-3 text-right transition ${
                        selectedRow
                          ? "border-[var(--soft)] bg-[#E8F5FC]"
                          : "border-[#D5E8F2] bg-[#F8FCFE]"
                      }`}
                      onClick={() => void openInvestment(item)}
                      disabled={busy}
                    >
                      <div className="mb-1 flex items-center justify-between gap-2">
                        <span className="text-[14px] font-extrabold text-[var(--basic)]">
                          {money(item.principal)}
                        </span>
                        <span
                          className="rounded-full px-2 py-0.5 text-[11px] font-extrabold"
                          style={{
                            color,
                            background: `${color}1F`,
                          }}
                        >
                          {statusLabel(item.status)}
                        </span>
                      </div>
                      <div className="text-[12px] font-bold text-[var(--basic)]/60">
                        فائدة {item.interest_percent}% · بعد الفائدة{" "}
                        {money(item.total_with_interest)}
                      </div>
                      <div className="mt-1 text-[11px] font-semibold text-[var(--basic)]/50">
                        قسط {money(item.monthly_payout)} · مستلم{" "}
                        {money(item.paid_amount)} · متبقي{" "}
                        {money(item.remaining_amount)}
                      </div>
                      <div className="mt-1 text-[11px] font-semibold text-[var(--basic)]/45">
                        من {formatDateString(item.start_date)} · أول قسط{" "}
                        {formatDateString(item.first_due_date)}
                      </div>
                    </button>
                  );
                })
              )}
            </div>

            {selected ? (
              <div className="rounded-2xl border border-[#D5E8F2] bg-white p-3">
                <div className="mb-2 flex items-center justify-between gap-2">
                  <h4 className="text-sm font-extrabold text-[var(--basic)]">
                    جدول أقساط العقد
                  </h4>
                  {isAdmin && unpaid.length > 0 ? (
                    <button
                      type="button"
                      className="rounded-xl bg-[var(--soft)] px-3 py-1.5 text-[11px] font-extrabold text-white disabled:opacity-60"
                      disabled={busy}
                      onClick={() => void onConfirmAll()}
                    >
                      تأكيد صرف المستحق
                    </button>
                  ) : null}
                </div>

                {(selected.payouts?.length ?? 0) === 0 ? (
                  <div className="py-4 text-center text-sm font-bold text-[var(--basic)]/50">
                    لا أقساط مستحقة بعد — أول قسط{" "}
                    {formatDateString(selected.first_due_date)}
                  </div>
                ) : (
                  <div className="space-y-2">
                    {selected.payouts!.map((p) => (
                      <div
                        key={p.id}
                        className="flex items-center gap-2 rounded-xl bg-[#F8FCFE] px-2.5 py-2"
                      >
                        <div className="w-14 text-[12px] font-extrabold">
                          قسط {p.installment_no}
                        </div>
                        <div className="flex-1 text-[12px] font-bold text-[var(--basic)]/60">
                          {formatDateString(p.due_date)}
                        </div>
                        <div className="text-[12px] font-extrabold">
                          {money(p.amount)}
                        </div>
                        <div
                          className={`text-[11px] font-extrabold ${
                            p.paid ? "text-[#0E8A61]" : "text-[#C62828]"
                          }`}
                        >
                          {p.paid ? "مصروف" : "مستحق"}
                        </div>
                        {isAdmin && !p.paid ? (
                          <button
                            type="button"
                            className="rounded-lg bg-[#E8F5FC] px-2 py-1 text-[11px] font-extrabold text-[var(--soft)] disabled:opacity-60"
                            disabled={busy}
                            onClick={() => void onConfirmOne(p.id)}
                          >
                            تأكيد
                          </button>
                        ) : null}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ) : null}
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
