"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  getInvestments,
  getInvestor,
} from "@/lib/api";
import {
  computeLastDueDate,
  formatDateString,
  installmentDueInMonth,
  money,
} from "@/lib/format";
import type { AppUser, Investment, Investor } from "@/lib/types";
import { InvestorDetailSheet } from "@/components/admin/InvestorDetailSheet";
import { MobileHeader } from "@/components/home/MobileHeader";
import { PromoBanner } from "@/components/home/PromoBanner";
import { SideMenu } from "@/components/home/SideMenu";
import { StatsGrid } from "@/components/home/StatsGrid";

type Props = {
  user: AppUser | null;
  onLogout: () => void;
};

function currentMonthDate() {
  const now = new Date();
  return new Date(Date.UTC(now.getFullYear(), now.getMonth(), 1));
}

function monthInputValue(d: Date) {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}`;
}

function dueForMonth(investments: Investment[], month: Date) {
  let total = 0;
  for (const item of investments) {
    if (item.status !== "active") continue;
    total += installmentDueInMonth({
      firstDue: item.first_due_date,
      monthsCount: item.months_count,
      monthlyPayment: item.monthly_payout,
      financedAmount: item.total_with_interest,
      month,
    });
  }
  return Number(total.toFixed(2));
}

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

export function InvestorHome({ user, onLogout }: Props) {
  const [investor, setInvestor] = useState<Investor | null>(null);
  const [investments, setInvestments] = useState<Investment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [detailOpen, setDetailOpen] = useState(false);
  const [selectedInvestmentId, setSelectedInvestmentId] = useState<
    string | null
  >(null);
  const [dueMonth, setDueMonth] = useState(currentMonthDate);
  const monthPickerRef = useRef<HTMLInputElement>(null);

  const load = useCallback(async () => {
    if (!user?.id) return;
    setLoading(true);
    setError(null);
    try {
      const [inv, list] = await Promise.all([
        getInvestor(user.id),
        getInvestments({ investor_id: user.id, page: 1, page_size: 50 }),
      ]);
      setInvestor(inv);
      setInvestments(list.items);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل البيانات");
    } finally {
      setLoading(false);
    }
  }, [user?.id]);

  useEffect(() => {
    void load();
  }, [load]);

  const nowMonth = currentMonthDate();
  const isCurrentDueMonth =
    dueMonth.getUTCFullYear() === nowMonth.getUTCFullYear() &&
    dueMonth.getUTCMonth() === nowMonth.getUTCMonth();
  const dueAmount = investments.length
    ? dueForMonth(investments, dueMonth)
    : isCurrentDueMonth
      ? (investor?.due_this_month_amount ?? 0)
      : 0;

  const statsForMenu = investor
    ? {
        total_customers: 0,
        completed_count: 0,
        remaining_count: 0,
        late_count: 0,
        pending_count: 0,
        total_amounts: investor.principal_total,
        paid_amounts: investor.paid_amount,
        remaining_amounts: investor.remaining_amount,
        bank_amounts: 0,
        platform_amounts: 0,
        financed_amounts: investor.total_with_interest,
        merchants_count: 0,
        investors_count: 1,
        investments_count: investor.investments_count,
        investor_principal_total: investor.principal_total,
        investor_total_with_interest: investor.total_with_interest,
        investor_paid_amount: investor.paid_amount,
        investor_remaining_amount: investor.remaining_amount,
        investor_due_this_month_amount: investor.due_this_month_amount,
      }
    : null;

  return (
    <main className="phone-shell pb-8">
      <MobileHeader
        user={user}
        onMenu={() => setMenuOpen(true)}
        onProfile={() => setMenuOpen(true)}
        roleLabel="مستثمر"
      />

      <PromoBanner
        title="مرحبا بك في نظام قسطلي💸"
        subtitle="عقودك الاستثمارية مستقلة، وأقساطك تُحتسب حسب كل عقد"
      />
      <input
        ref={monthPickerRef}
        type="month"
        className="sr-only"
        value={monthInputValue(dueMonth)}
        onChange={(e) => {
          const [y, m] = e.target.value.split("-").map(Number);
          if (!y || !m) return;
          setDueMonth(new Date(Date.UTC(y, m - 1, 1)));
        }}
      />
      <StatsGrid
        stats={statsForMenu}
        variant="investor"
        investorDueAmount={dueAmount}
        investorDueSubtitle={
          isCurrentDueMonth
            ? null
            : `${String(dueMonth.getUTCMonth() + 1).padStart(2, "0")}/${dueMonth.getUTCFullYear()}`
        }
        onPickInvestorDueMonth={() => {
          const el = monthPickerRef.current;
          if (!el) return;
          if (typeof el.showPicker === "function") {
            el.showPicker();
          } else {
            el.click();
          }
        }}
      />

      {loading ? (
        <div className="mx-4 mt-10 text-center text-sm font-bold text-[var(--soft)]">
          جاري التحميل...
        </div>
      ) : error ? (
        <div className="mx-4 mt-5 rounded-2xl bg-white p-4 text-center text-sm font-bold text-[var(--late)]">
          {error}
          <button
            type="button"
            className="mt-2 block w-full text-[var(--soft)]"
            onClick={() => void load()}
          >
            إعادة المحاولة
          </button>
        </div>
      ) : (
        <>
          <section className="mx-4 mt-5">
            <div className="mb-3 flex items-center gap-2">
              <h2 className="text-[17px] font-extrabold text-[var(--basic)]">
                عقودي الاستثمارية
              </h2>
              <span className="rounded-full bg-[#E8F5FC] px-2.5 py-1 text-[11px] font-extrabold text-[var(--soft)]">
                {investments.length}
              </span>
            </div>

            {investments.length === 0 ? (
              <div className="rounded-2xl bg-white p-8 text-center text-sm font-bold text-[var(--basic)]/50">
                لا توجد عقود استثمار بعد. عند إضافة عقد من الإدارة سيظهر هنا.
              </div>
            ) : (
              <div className="space-y-3">
                {investments.map((item, index) => {
                  const color = statusColor(item.status);
                  return (
                    <article
                      key={item.id}
                      className="customer-card cursor-pointer transition active:scale-[0.99]"
                      role="button"
                      tabIndex={0}
                      onClick={() => {
                        setSelectedInvestmentId(item.id);
                        setDetailOpen(true);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === "Enter" || e.key === " ") {
                          e.preventDefault();
                          setSelectedInvestmentId(item.id);
                          setDetailOpen(true);
                        }
                      }}
                    >
                      <div className="mb-2 flex items-start justify-between gap-2">
                        <div className="flex items-center gap-2">
                          <div className="grid h-8 w-8 place-items-center rounded-full bg-[#E3F4FB] text-[12px] font-extrabold text-[var(--soft)]">
                            {String(index + 1).padStart(2, "0")}
                          </div>
                          <div>
                            <div className="text-[15px] font-extrabold text-[var(--basic)]">
                              {money(item.principal)}
                            </div>
                            <div className="text-[12px] font-bold text-[var(--basic)]/55">
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

                      <div className="grid grid-cols-2 gap-2 rounded-2xl bg-[#F7FBFD] px-2 py-3 text-center">
                        <div>
                          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
                            بعد الفائدة
                          </div>
                          <div className="text-[13px] font-extrabold">
                            {money(item.total_with_interest)}
                          </div>
                        </div>
                        <div>
                          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
                            القسط الشهري
                          </div>
                          <div className="text-[13px] font-extrabold">
                            {money(item.monthly_payout)}
                          </div>
                        </div>
                        <div>
                          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
                            المستلم
                          </div>
                          <div className="text-[13px] font-extrabold text-[#0E8A61]">
                            {money(item.paid_amount)}
                          </div>
                        </div>
                        <div>
                          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
                            المتبقي
                          </div>
                          <div className="text-[13px] font-extrabold text-[#C38508]">
                            {money(item.remaining_amount)}
                          </div>
                        </div>
                      </div>

                      <div className="mt-2 text-[11px] font-semibold text-[var(--basic)]/50">
                        من {formatDateString(item.start_date)} · أول قسط{" "}
                        {formatDateString(item.first_due_date)} · آخر قسط{" "}
                        {formatDateString(
                          computeLastDueDate(
                            item.first_due_date,
                            item.months_count,
                          ),
                        )}{" "}
                        · {item.remaining_months}/{item.months_count} شهر
                      </div>
                    </article>
                  );
                })}
              </div>
            )}
          </section>
        </>
      )}

      <SideMenu
        open={menuOpen}
        user={user}
        stats={statsForMenu}
        variant="investor"
        onClose={() => setMenuOpen(false)}
        onLogout={onLogout}
      />

      <InvestorDetailSheet
        open={detailOpen}
        investorId={user?.id ?? null}
        isAdmin={false}
        initialInvestmentId={selectedInvestmentId}
        onClose={() => {
          setDetailOpen(false);
          setSelectedInvestmentId(null);
        }}
        onUpdated={() => void load()}
      />
    </main>
  );
}
