"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import {
  confirmMerchantDues,
  getCustomers,
  getMerchant,
} from "@/lib/api";
import { money, statusLabel } from "@/lib/format";
import type { Customer, Merchant } from "@/lib/types";
import { AddMerchantSheet } from "@/components/admin/AddMerchantSheet";
import { CustomerDetailSheet } from "@/components/home/CustomerDetailSheet";

type Props = {
  merchantId: string | null;
  open: boolean;
  onClose: () => void;
  onUpdated?: () => void;
};

function MetaItem({ label, value }: { label: string; value: string }) {
  return (
    <div className="cd-meta-item">
      <span className="cd-meta-label">{label}</span>
      <span className="cd-meta-value">{value}</span>
    </div>
  );
}

function MoneyTile({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone: "green" | "blue" | "red" | "cyan" | "purple" | "gold";
}) {
  return (
    <div className={`cd-money-tile tone-${tone}`}>
      <span className="cd-money-label">{label}</span>
      <span className="cd-money-value">{value}</span>
    </div>
  );
}

export function MerchantDetailSheet({
  merchantId,
  open,
  onClose,
  onUpdated,
}: Props) {
  const [merchant, setMerchant] = useState<Merchant | null>(null);
  const [plans, setPlans] = useState<Customer[]>([]);
  const [activeCount, setActiveCount] = useState(0);
  const [completedCount, setCompletedCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [confirming, setConfirming] = useState(false);
  const [payAmount, setPayAmount] = useState("");
  const [editOpen, setEditOpen] = useState(false);
  const [planId, setPlanId] = useState<string | null>(null);

  async function load(id: string) {
    setLoading(true);
    setError(null);
    try {
      const [m, allPlans, active, inactive, completed] = await Promise.all([
        getMerchant(id),
        getCustomers({ merchant_id: id, page: 1, page_size: 20 }),
        getCustomers({
          merchant_id: id,
          status: "active",
          page: 1,
          page_size: 1,
        }),
        getCustomers({
          merchant_id: id,
          status: "inactive",
          page: 1,
          page_size: 1,
        }),
        getCustomers({
          merchant_id: id,
          status: "completed",
          page: 1,
          page_size: 1,
        }),
      ]);
      setMerchant(m);
      setPayAmount(
        m.due_this_month_amount > 0 ? String(m.due_this_month_amount) : "",
      );
      setPlans(allPlans.items);
      setActiveCount(active.total + inactive.total);
      setCompletedCount(completed.total);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل ملف التاجر");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    if (!open || !merchantId) return;
    setEditOpen(false);
    setPlanId(null);
    void load(merchantId);
  }, [open, merchantId]);

  if (!open) return null;

  const whatsapp = merchant?.phone
    ? `https://wa.me/964${merchant.phone.replace(/^0/, "")}`
    : null;
  const confirmed = Boolean(merchant?.due_confirmed_this_month);
  const dueAmount = merchant?.due_this_month_amount ?? 0;
  const carried = merchant?.due_carried_amount ?? 0;

  async function onConfirmDues() {
    if (!merchant || confirming || confirmed || dueAmount <= 0) return;
    const raw = payAmount.trim().replace(/,/g, "");
    const amount = Number(raw);
    if (!Number.isFinite(amount) || amount <= 0) {
      setError("أدخل مبلغ تسديد صالحاً");
      return;
    }
    if (amount > dueAmount + 0.01) {
      setError(`مبلغ التسديد أكبر من المستحقات (${money(dueAmount)} د.ع)`);
      return;
    }
    const carriedNote =
      carried > 0 ? `\nمنها مرحّل: ${money(carried)} د.ع` : "";
    const ok = window.confirm(
      amount + 0.01 >= dueAmount
        ? `تسديد المستحقات بالكامل (${money(dueAmount)} د.ع)؟${carriedNote}`
        : `تسديد ${money(amount)} د.ع من أصل ${money(dueAmount)} د.ع؟${carriedNote}\nالمتبقي سيبقى مستحقاً وتُضاف عليه الخطط الجديدة.`,
    );
    if (!ok) return;
    setConfirming(true);
    setError(null);
    try {
      const updated = await confirmMerchantDues(merchant.id, amount);
      setMerchant(updated);
      setPayAmount(
        updated.due_this_month_amount > 0
          ? String(updated.due_this_month_amount)
          : "",
      );
      onUpdated?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تأكيد المستحقات");
    } finally {
      setConfirming(false);
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
        className="center-dialog customer-detail-dialog"
        role="dialog"
        aria-modal="true"
      >
        <header className="cd-hero">
          <Image
            src="/images/3D Clipboard and Gold Coin Stacks.png"
            alt=""
            fill
            className="cd-hero-img"
            priority
          />
          <div className="cd-hero-shade" />
          <button
            type="button"
            className="cd-close"
            onClick={onClose}
            aria-label="إغلاق"
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <path
                d="M3 3L11 11M11 3L3 11"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
              />
            </svg>
          </button>
          <div className="cd-hero-copy">
            <div className="cd-hero-title-row">
              <h3>ملف التاجر</h3>
              <span className="cd-hero-badge" aria-hidden>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M10 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-8l-2-2Z" />
                </svg>
              </span>
            </div>
            <p>معلومات التاجر وخطط زبائنه وإحصائياته</p>
          </div>
        </header>

        <div className="customer-detail-body">
          {loading ? (
            <div className="cd-state">جاري التحميل...</div>
          ) : error && !merchant ? (
            <div className="cd-state error">{error}</div>
          ) : merchant ? (
            <>
              {error ? (
                <div className="rounded-2xl bg-[#FDECEC] px-3 py-2 text-center text-sm font-bold text-[var(--late)]">
                  {error}
                </div>
              ) : null}

              <section className="cd-identity">
                <div className="cd-identity-top">
                  <div className="min-w-0 flex-1">
                    <h4 className="cd-name">{merchant.full_name}</h4>
                    <div className="mt-0.5 text-[12px] font-bold text-[var(--basic)]/50">
                      @{merchant.username}
                    </div>
                    {merchant.phone ? (
                      <a href={`tel:${merchant.phone}`} className="cd-phone">
                        {merchant.phone}
                      </a>
                    ) : null}
                  </div>
                  <span
                    className="status-pill"
                    style={
                      merchant.active
                        ? undefined
                        : { background: "#FDECEC", color: "#C0392B" }
                    }
                  >
                    {merchant.active ? "نشط" : "موقوف"}
                  </span>
                </div>
                <div className="cd-actions">
                  <button
                    type="button"
                    className="cd-btn-edit"
                    onClick={() => setEditOpen(true)}
                  >
                    تعديل المعلومات
                  </button>
                  {whatsapp ? (
                    <a
                      href={whatsapp}
                      target="_blank"
                      rel="noreferrer"
                      className="cd-btn-wa"
                    >
                      واتساب
                    </a>
                  ) : (
                    <button type="button" className="cd-btn-wa opacity-50" disabled>
                      واتساب
                    </button>
                  )}
                </div>
              </section>

              <section className="cd-card">
                <h5 className="cd-section-title">البيانات الأساسية</h5>
                <div className="cd-meta-grid">
                  <MetaItem
                    label="المحافظة"
                    value={merchant.governorate || "—"}
                  />
                  <MetaItem label="العنوان" value={merchant.address || "—"} />
                  <MetaItem
                    label="رقم الماستر"
                    value={merchant.master_card || "—"}
                  />
                  <MetaItem label="اسم المستخدم" value={merchant.username} />
                </div>
              </section>

              <section className="cd-card">
                <h5 className="cd-section-title">ملخص الخطط</h5>
                <div className="cd-money-grid">
                  <MoneyTile
                    label="عدد الخطط"
                    value={`${merchant.customers_count}`}
                    tone="blue"
                  />
                  <MoneyTile
                    label="الخطط النشطة"
                    value={`${activeCount}`}
                    tone="cyan"
                  />
                  <MoneyTile
                    label="الخطط المكتملة"
                    value={`${completedCount}`}
                    tone="green"
                  />
                  <MoneyTile
                    label="إجمالي الخطط"
                    value={`${money(merchant.total_amounts)} د.ع`}
                    tone="purple"
                  />
                </div>
              </section>

              <section className="cd-card">
                <h5 className="cd-section-title">النسب والمبالغ</h5>
                <div className="cd-split-list">
                  <div className="cd-split-row">
                    <span>نسبة المصرف ({merchant.bank_percent}%)</span>
                    <strong>{money(merchant.bank_amounts)} د.ع</strong>
                  </div>
                  <div className="cd-split-row">
                    <span>نسبة المنصة ({merchant.platform_percent}%)</span>
                    <strong>{money(merchant.platform_amounts)} د.ع</strong>
                  </div>
                  <div className="cd-split-row">
                    <span>
                      نسبة المستثمر ({merchant.investor_percent ?? 0}%)
                    </span>
                    <strong>
                      {money(merchant.investor_amounts ?? 0)} د.ع
                    </strong>
                  </div>
                  <div className="cd-split-row">
                    <span>المسدد من الأقساط</span>
                    <strong>{money(merchant.paid_amounts)} د.ع</strong>
                  </div>
                  <div className="cd-split-row highlight">
                    <span>المتبقي على الزبائن</span>
                    <strong>{money(merchant.remaining_amounts)} د.ع</strong>
                  </div>
                </div>
              </section>

              <section className="cd-card" style={{ background: "#FFF4E5" }}>
                <h5 className="cd-section-title" style={{ color: "#C38508" }}>
                  {carried > 0
                    ? `مستحقات فورية (${merchant.due_this_month_count} زبون) • متبقي بعد تسديد جزئي ${money(carried)} د.ع`
                    : `مستحقات فورية نقداً (${merchant.due_this_month_count} زبون) = المبالغ بعد النسب − المسدّد`}
                </h5>
                <div className="mb-3 text-[18px] font-extrabold text-[#0B3A5C]">
                  {money(dueAmount)} د.ع
                </div>
                {confirmed ? (
                  <div className="inline-flex h-11 items-center justify-center gap-2 rounded-xl border border-[#9AD4B8] bg-[#E7F7EF] px-4 text-[13px] font-extrabold text-[#0E8A61]">
                    تم التأكيد
                  </div>
                ) : (
                  <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
                    <input
                      type="number"
                      min={0}
                      step="any"
                      className="h-11 w-full rounded-xl border border-[#E8D4B0] bg-white px-3 text-[13px] font-bold text-[#0B3A5C] sm:max-w-[200px]"
                      placeholder="مبلغ التسديد"
                      value={payAmount}
                      onChange={(e) => setPayAmount(e.target.value)}
                      disabled={confirming}
                    />
                    <button
                      type="button"
                      className="h-11 rounded-xl bg-[#0E8A61] px-4 text-[13px] font-extrabold text-white disabled:opacity-50"
                      disabled={dueAmount <= 0 || confirming}
                      onClick={() => void onConfirmDues()}
                    >
                      {confirming ? "جاري التسديد..." : "تسديد"}
                    </button>
                  </div>
                )}
              </section>

              <section className="cd-card">
                <div className="cd-payments-head">
                  <h5 className="cd-section-title mb-0">خطط الزبائن</h5>
                  <span className="cd-count">{plans.length}</span>
                </div>
                {plans.length === 0 ? (
                  <p className="cd-empty">لا توجد خطط زبائن لهذا التاجر</p>
                ) : (
                  <div className="space-y-2">
                    {plans.map((c) => (
                      <button
                        key={c.id}
                        type="button"
                        className="w-full rounded-2xl border border-[#EAF3F8] bg-[#F7FBFD] px-3 py-3 text-right"
                        onClick={() => setPlanId(c.id)}
                      >
                        <div className="mb-1 flex items-center justify-between gap-2">
                          <span className="truncate text-[13px] font-extrabold text-[#0B3A5C]">
                            {c.name}
                          </span>
                          <span className="status-pill shrink-0">
                            {statusLabel(c.status)}
                          </span>
                        </div>
                        <div className="grid grid-cols-2 gap-2 text-[12px]">
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              الهاتف
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {c.phone}
                            </div>
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              المبلغ الكلي
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {money(c.total_amount)} د.ع
                            </div>
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              مستحق التاجر
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {money(c.financed_amount ?? 0)} د.ع
                            </div>
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              استحقاق التاجر
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {c.status === "pending" || c.status === "rejected"
                                ? "—"
                                : "فوري"}
                            </div>
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              أشهر الزبون
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {c.months_count}
                            </div>
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              قسط الزبون
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {money(c.monthly_payment)} د.ع
                            </div>
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              المتبقي على الزبون
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {money(c.remaining_amount)} د.ع
                            </div>
                          </div>
                          <div>
                            <div className="font-semibold text-[var(--basic)]/45">
                              التسجيل
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {c.registration_date
                                ? new Date(
                                    c.registration_date,
                                  ).toLocaleDateString("ar-IQ")
                                : "—"}
                            </div>
                          </div>
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </section>
            </>
          ) : null}
        </div>
      </div>

      <AddMerchantSheet
        open={editOpen}
        merchant={merchant}
        onClose={() => setEditOpen(false)}
        onSaved={() => {
          if (merchantId) void load(merchantId);
          onUpdated?.();
        }}
      />

      <CustomerDetailSheet
        open={Boolean(planId)}
        customerId={planId}
        isAdmin
        onClose={() => setPlanId(null)}
        onUpdated={() => {
          if (merchantId) void load(merchantId);
          onUpdated?.();
        }}
      />
    </>
  );
}
