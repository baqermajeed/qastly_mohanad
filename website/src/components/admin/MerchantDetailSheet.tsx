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
    const ok = window.confirm(
      `تأكيد استلام مستحقات التاجر (${money(dueAmount)} د.ع) لهذا الشهر؟`,
    );
    if (!ok) return;
    setConfirming(true);
    try {
      const updated = await confirmMerchantDues(merchant.id);
      setMerchant(updated);
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
            <p>معلومات التاجر وخطط الأقساط وإحصائياته</p>
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
                    ? `مستحقات معلّقة (${merchant.due_this_month_count} خطة) • مرحّل ${money(carried)} د.ع`
                    : `مبلغ الدفعات المستحقة هذا الشهر (${merchant.due_this_month_count} خطة)`}
                </h5>
                <div className="mb-3 text-[18px] font-extrabold text-[#0B3A5C]">
                  {money(dueAmount)} د.ع
                </div>
                {confirmed ? (
                  <div className="inline-flex h-11 items-center justify-center gap-2 rounded-xl border border-[#9AD4B8] bg-[#E7F7EF] px-4 text-[13px] font-extrabold text-[#0E8A61]">
                    تم التأكيد
                  </div>
                ) : (
                  <button
                    type="button"
                    className="h-11 rounded-xl bg-[#0E8A61] px-4 text-[13px] font-extrabold text-white disabled:opacity-50"
                    disabled={dueAmount <= 0 || confirming}
                    onClick={() => void onConfirmDues()}
                  >
                    {confirming ? "جاري التأكيد..." : "تأكيد الدفع"}
                  </button>
                )}
              </section>

              <section className="cd-card">
                <div className="cd-payments-head">
                  <h5 className="cd-section-title mb-0">خطط التاجر</h5>
                  <span className="cd-count">{plans.length}</span>
                </div>
                {plans.length === 0 ? (
                  <p className="cd-empty">لا توجد خطط لهذا التاجر</p>
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
                              المتبقي
                            </div>
                            <div className="font-extrabold text-[#0B3A5C]">
                              {money(c.remaining_amount)} د.ع
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
