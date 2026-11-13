"use client";

import { FormEvent, useEffect, useState } from "react";
import { createInvestor, updateInvestor } from "@/lib/api";
import type { Investor } from "@/lib/types";

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
  investor?: Investor | null;
};

export function AddInvestorSheet({
  open,
  onClose,
  onSaved,
  investor = null,
}: Props) {
  const editing = Boolean(investor);
  const [fullName, setFullName] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");
  const [masterCard, setMasterCard] = useState("");
  const [note, setNote] = useState("");
  const [active, setActive] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setError(null);
    setPassword("");
    if (investor) {
      setFullName(investor.full_name);
      setUsername(investor.username);
      setPhone(investor.phone || "");
      setMasterCard(investor.master_card || "");
      setNote(investor.note || "");
      setActive(investor.active);
    } else {
      setFullName("");
      setUsername("");
      setPhone("");
      setMasterCard("");
      setNote("");
      setActive(true);
    }
  }, [open, investor]);

  if (!open) return null;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);

    if (!/^\d{11}$/.test(phone.trim())) {
      setError("أدخل رقم هاتف عراقي صحيح (11 رقم)");
      return;
    }
    if (!/^\d{8,19}$/.test(masterCard.trim())) {
      setError("رقم الماستر غير صالح");
      return;
    }
    if (!editing && password.trim().length < 4) {
      setError("كلمة المرور 4 أحرف على الأقل");
      return;
    }

    setBusy(true);
    try {
      if (editing && investor) {
        await updateInvestor(investor.id, {
          full_name: fullName.trim(),
          phone: phone.trim(),
          master_card: masterCard.trim(),
          note: note.trim(),
          active,
          ...(password.trim() ? { password: password.trim() } : {}),
        });
      } else {
        await createInvestor({
          full_name: fullName.trim(),
          username: username.trim().toLowerCase(),
          password,
          phone: phone.trim(),
          master_card: masterCard.trim(),
          note: note.trim(),
        });
      }
      onSaved();
      onClose();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : editing
            ? "تعذر تعديل المستثمر"
            : "تعذر إضافة المستثمر",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <button
        type="button"
        className="sheet-backdrop is-open"
        style={{ zIndex: 60 }}
        aria-label="إغلاق"
        onClick={onClose}
      />
      <div
        className="center-dialog max-h-[88dvh] w-[min(calc(100%-28px),400px)]"
        style={{ zIndex: 61 }}
        role="dialog"
        aria-modal="true"
      >
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="text-base font-extrabold text-[var(--basic)]">
            {editing ? "تعديل المستثمر" : "إضافة مستثمر"}
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
          حساب دخول للمستثمر. العقود الاستثمارية تُضاف لاحقاً بشكل منفصل.
        </p>

        <form onSubmit={onSubmit} className="space-y-2.5">
          <input
            className="field"
            placeholder="اسم المستثمر"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            required
          />
          <input
            className="field"
            placeholder="رقم الهاتف"
            value={phone}
            onChange={(e) =>
              setPhone(e.target.value.replace(/\D/g, "").slice(0, 11))
            }
            inputMode="numeric"
            required
          />
          <input
            className="field"
            placeholder="رقم الماستر كارد"
            value={masterCard}
            onChange={(e) =>
              setMasterCard(e.target.value.replace(/\D/g, "").slice(0, 19))
            }
            inputMode="numeric"
            required
          />
          <input
            className="field"
            placeholder="اسم المستخدم"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            required
            disabled={editing}
          />
          <input
            className="field"
            placeholder={
              editing ? "كلمة مرور جديدة (اختياري)" : "كلمة المرور"
            }
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required={!editing}
            minLength={editing ? undefined : 4}
          />
          <textarea
            className="field min-h-[72px]"
            placeholder="ملاحظة (اختياري)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
          {editing ? (
            <label className="flex items-center gap-2 text-sm font-bold text-[var(--basic)]">
              <input
                type="checkbox"
                checked={active}
                onChange={(e) => setActive(e.target.checked)}
              />
              الحساب نشط
            </label>
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
            <button
              type="submit"
              className="btn-primary h-11"
              disabled={busy}
            >
              {busy
                ? "جاري الحفظ..."
                : editing
                  ? "حفظ التعديلات"
                  : "إضافة المستثمر"}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
