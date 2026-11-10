"use client";

import { FormEvent, useEffect, useState } from "react";
import Image from "next/image";
import { getCustomer, updateCustomer } from "@/lib/api";
import {
  formatDateString,
  iraqiGovernorates,
  money,
  paymentMethodLabel,
  statusLabel,
} from "@/lib/format";
import type { Customer } from "@/lib/types";

type Props = {
  customerId: string | null;
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
  tone: "green" | "blue" | "red" | "cyan" | "purple";
}) {
  return (
    <div className={`cd-money-tile tone-${tone}`}>
      <span className="cd-money-label">{label}</span>
      <span className="cd-money-value">{value}</span>
    </div>
  );
}

export function CustomerDetailSheet({
  customerId,
  open,
  onClose,
  onUpdated,
}: Props) {
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [governorate, setGovernorate] = useState("");
  const [mastercard, setMastercard] = useState("");
  const [nationalId, setNationalId] = useState("");

  useEffect(() => {
    if (!open || !customerId) return;
    let cancelled = false;
    setLoading(true);
    setError(null);
    setEditing(false);
    void getCustomer(customerId)
      .then((data) => {
        if (cancelled) return;
        setCustomer(data);
      })
      .catch((err) => {
        if (cancelled) return;
        setError(err instanceof Error ? err.message : "تعذر تحميل الملف");
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, customerId]);

  if (!open) return null;

  function startEdit(c: Customer) {
    setName(c.name);
    setPhone(c.phone);
    setGovernorate(c.governorate);
    setMastercard(c.mastercard_number || "");
    setNationalId(c.national_id || "");
    setEditError(null);
    setEditing(true);
  }

  async function onSave(e: FormEvent) {
    e.preventDefault();
    if (!customer) return;
    setEditError(null);
    const cleanedName = name.trim().replace(/\s+/g, " ");
    if (cleanedName.length < 3) {
      setEditError("أدخل الاسم الثلاثي للزبون");
      return;
    }
    if (!/^\d{11}$/.test(phone.trim())) {
      setEditError("أدخل رقم هاتف عراقي صحيح (11 رقم)");
      return;
    }
    if (!governorate) {
      setEditError("اختر المحافظة");
      return;
    }

    setSaving(true);
    try {
      const updated = await updateCustomer(customer.id, {
        name: cleanedName,
        phone: phone.trim(),
        governorate,
        mastercard_number: mastercard.trim(),
        national_id: nationalId.trim(),
      });
      setCustomer({ ...customer, ...updated, payments: customer.payments });
      setEditing(false);
      onUpdated?.();
    } catch (err) {
      setEditError(err instanceof Error ? err.message : "تعذر حفظ التعديلات");
    } finally {
      setSaving(false);
    }
  }

  const payments = customer?.payments ?? [];
  const firstDue = formatDateString(customer?.first_due_date);

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
              <h3>ملف الزبون</h3>
              <span className="cd-hero-badge" aria-hidden>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M10 4H4a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-8l-2-2Z" />
                </svg>
              </span>
            </div>
            <p>معلومات الزبون والدفعات التلقائية</p>
          </div>
        </header>

        <div className="customer-detail-body">
          {loading ? (
            <div className="cd-state">جاري التحميل...</div>
          ) : error ? (
            <div className="cd-state error">{error}</div>
          ) : customer ? (
            <>
              <section className="cd-identity">
                <div className="cd-identity-top">
                  <div className="min-w-0 flex-1">
                    <h4 className="cd-name">{customer.name}</h4>
                    <a href={`tel:${customer.phone}`} className="cd-phone">
                      {customer.phone}
                    </a>
                  </div>
                  <span className="status-pill">{statusLabel(customer.status)}</span>
                </div>
                <div className="cd-actions">
                  <button
                    type="button"
                    className="cd-btn-edit"
                    onClick={() => startEdit(customer)}
                  >
                    تعديل المعلومات
                  </button>
                  <a
                    href={customer.whatsapp_url}
                    target="_blank"
                    rel="noreferrer"
                    className="cd-btn-wa"
                  >
                    واتساب
                  </a>
                </div>
              </section>

              <section className="cd-card">
                <h5 className="cd-section-title">البيانات الأساسية</h5>
                <div className="cd-meta-grid">
                  <MetaItem label="المحافظة" value={customer.governorate} />
                  <MetaItem
                    label="حالة الخطة"
                    value={statusLabel(customer.status)}
                  />
                  <MetaItem
                    label="رقم الماستر كارد"
                    value={customer.mastercard_number || "—"}
                  />
                  <MetaItem
                    label="رقم البطاقة الوطنية"
                    value={customer.national_id || "—"}
                  />
                </div>
              </section>

              <section className="cd-card">
                <h5 className="cd-section-title">ملخص التقسيط</h5>
                <div className="cd-money-grid">
                  <MoneyTile
                    label="المبلغ الكلي"
                    value={`${money(customer.total_amount)} د.ع`}
                    tone="green"
                  />
                  <MoneyTile
                    label="المبلغ المتبقي"
                    value={`${money(customer.remaining_amount)} د.ع`}
                    tone="red"
                  />
                  <MoneyTile
                    label="عدد الأشهر"
                    value={`${customer.months_count} شهر`}
                    tone="blue"
                  />
                  <MoneyTile
                    label="الأشهر المتبقية"
                    value={`${customer.remaining_months} شهر`}
                    tone="cyan"
                  />
                  <MoneyTile
                    label="الدفعة الشهرية"
                    value={`${money(customer.monthly_payment)} د.ع`}
                    tone="purple"
                  />
                </div>
              </section>

              <section className="cd-card">
                <h5 className="cd-section-title">توزيع المبالغ</h5>
                <div className="cd-split-list">
                  <div className="cd-split-row">
                    <span>نسبة المصرف ({customer.bank_percent ?? 0}%)</span>
                    <strong>{money(customer.bank_amount ?? 0)} د.ع</strong>
                  </div>
                  <div className="cd-split-row">
                    <span>نسبة المنصة ({customer.platform_percent ?? 0}%)</span>
                    <strong>{money(customer.platform_amount ?? 0)} د.ع</strong>
                  </div>
                  <div className="cd-split-row highlight">
                    <span>المبلغ بعد النسب</span>
                    <strong>{money(customer.financed_amount ?? 0)} د.ع</strong>
                  </div>
                  <div className="cd-split-row">
                    <span>أول دفعة</span>
                    <strong>{firstDue}</strong>
                  </div>
                  <div className="cd-split-row">
                    <span>الدفعة القادمة</span>
                    <strong>
                      {customer.next_due_date
                        ? formatDateString(customer.next_due_date)
                        : "لا توجد"}
                    </strong>
                  </div>
                </div>
              </section>

              <section className="cd-card">
                <div className="cd-payments-head">
                  <h5 className="cd-section-title mb-0">سجل الدفعات التلقائية</h5>
                  <span className="cd-count">{payments.length}</span>
                </div>

                {payments.length === 0 ? (
                  <p className="cd-empty">
                    {customer.first_due_date
                      ? `لا توجد دفعات بعد — أول دفعة يوم ${firstDue}`
                      : "لا توجد دفعات بعد"}
                  </p>
                ) : (
                  <div className="cd-payments">
                    {payments.map((p, i) => (
                      <div key={p.id} className="cd-payment">
                        <div className="cd-payment-top">
                          <span className="cd-payment-no">#{i + 1}</span>
                          <span className="cd-method">
                            {paymentMethodLabel(p.method)}
                          </span>
                        </div>
                        <div className="cd-payment-grid">
                          <div>
                            <span>تاريخ التسديد</span>
                            <strong>{formatDateString(p.payment_date)}</strong>
                          </div>
                          <div>
                            <span>مبلغ الدفعة</span>
                            <strong>{money(p.amount)} د.ع</strong>
                          </div>
                        </div>
                        <div className="cd-payment-note">
                          {p.note?.trim() || "بدون ملاحظة"}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </section>
            </>
          ) : null}
        </div>
      </div>

      {editing ? (
        <>
          <button
            type="button"
            className="sheet-backdrop is-open"
            style={{ zIndex: 60 }}
            aria-label="إغلاق التعديل"
            onClick={() => setEditing(false)}
          />
          <div
            className="center-dialog"
            style={{ zIndex: 61, width: "min(calc(100% - 28px), 380px)" }}
            role="dialog"
            aria-modal="true"
          >
            <div className="mb-3 flex items-center justify-between">
              <h3 className="text-base font-extrabold text-[var(--basic)]">
                تعديل المعلومات
              </h3>
              <button
                type="button"
                className="grid h-8 w-8 place-items-center rounded-xl bg-[#EAF6FB] text-sm font-bold"
                onClick={() => setEditing(false)}
              >
                ✕
              </button>
            </div>
            <form onSubmit={onSave} className="space-y-2.5">
              <div>
                <label className="mb-1 block text-xs font-bold">الاسم</label>
                <input
                  className="field"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  required
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">رقم الهاتف</label>
                <input
                  className="field"
                  value={phone}
                  onChange={(e) =>
                    setPhone(e.target.value.replace(/\D/g, "").slice(0, 11))
                  }
                  inputMode="numeric"
                  required
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">المحافظة</label>
                <select
                  className="field"
                  value={governorate}
                  onChange={(e) => setGovernorate(e.target.value)}
                  required
                >
                  {iraqiGovernorates.map((g) => (
                    <option key={g} value={g}>
                      {g}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  رقم الماستر كارد
                </label>
                <input
                  className="field"
                  value={mastercard}
                  onChange={(e) =>
                    setMastercard(e.target.value.replace(/\D/g, "").slice(0, 19))
                  }
                  inputMode="numeric"
                />
              </div>
              <div>
                <label className="mb-1 block text-xs font-bold">
                  رقم البطاقة الوطنية
                </label>
                <input
                  className="field"
                  value={nationalId}
                  onChange={(e) =>
                    setNationalId(e.target.value.replace(/\D/g, "").slice(0, 20))
                  }
                  inputMode="numeric"
                />
              </div>
              {editError ? (
                <p className="text-center text-sm font-bold text-[var(--late)]">
                  {editError}
                </p>
              ) : null}
              <div className="grid grid-cols-2 gap-2 pt-1">
                <button
                  type="button"
                  className="btn-filter w-full justify-center"
                  onClick={() => setEditing(false)}
                >
                  إلغاء
                </button>
                <button
                  type="submit"
                  className="btn-primary w-full whitespace-nowrap text-[13px]"
                  disabled={saving}
                >
                  {saving ? "جاري الحفظ..." : "حفظ"}
                </button>
              </div>
            </form>
          </div>
        </>
      ) : null}
    </>
  );
}
