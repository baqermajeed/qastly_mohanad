"use client";

import { FormEvent, useEffect, useState } from "react";
import { createMerchant, updateMerchant } from "@/lib/api";
import { iraqiGovernorates } from "@/lib/format";
import type { Merchant } from "@/lib/types";

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved: () => void;
  merchant?: Merchant | null;
};

export function AddMerchantSheet({
  open,
  onClose,
  onSaved,
  merchant = null,
}: Props) {
  const editing = Boolean(merchant);
  const [fullName, setFullName] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");
  const [governorate, setGovernorate] = useState("");
  const [address, setAddress] = useState("");
  const [masterCard, setMasterCard] = useState("");
  const [bankPercent, setBankPercent] = useState("10");
  const [platformPercent, setPlatformPercent] = useState("5");
  const [active, setActive] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setError(null);
    setPassword("");
    if (merchant) {
      setFullName(merchant.full_name);
      setUsername(merchant.username);
      setPhone(merchant.phone || "");
      setGovernorate(merchant.governorate || "");
      setAddress(merchant.address || "");
      setMasterCard(merchant.master_card || "");
      setBankPercent(String(merchant.bank_percent ?? 0));
      setPlatformPercent(String(merchant.platform_percent ?? 0));
      setActive(merchant.active);
    } else {
      setFullName("");
      setUsername("");
      setPhone("");
      setGovernorate("");
      setAddress("");
      setMasterCard("");
      setBankPercent("10");
      setPlatformPercent("5");
      setActive(true);
    }
  }, [open, merchant]);

  if (!open) return null;

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);

    const bank = Number(bankPercent);
    const platform = Number(platformPercent);
    if (!Number.isFinite(bank) || !Number.isFinite(platform)) {
      setError("أدخل نسب صحيحة");
      return;
    }
    if (bank + platform >= 100) {
      setError("مجموع نسبة المصرف والمنصة يجب أن يكون أقل من 100");
      return;
    }
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
      if (editing && merchant) {
        await updateMerchant(merchant.id, {
          full_name: fullName.trim(),
          phone: phone.trim(),
          governorate,
          address: address.trim(),
          master_card: masterCard.trim(),
          bank_percent: bank,
          platform_percent: platform,
          active,
          ...(password.trim() ? { password: password.trim() } : {}),
        });
      } else {
        await createMerchant({
          full_name: fullName.trim(),
          username: username.trim().toLowerCase(),
          password,
          phone: phone.trim(),
          governorate,
          address: address.trim(),
          master_card: masterCard.trim(),
          bank_percent: bank,
          platform_percent: platform,
        });
      }
      onSaved();
      onClose();
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : editing
            ? "تعذر تعديل التاجر"
            : "تعذر إضافة التاجر",
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
            {editing ? "تعديل التاجر" : "إضافة تاجر"}
          </h3>
          <button
            type="button"
            onClick={onClose}
            className="grid h-8 w-8 place-items-center rounded-xl bg-[#EAF6FB] text-sm font-bold"
          >
            ✕
          </button>
        </div>

        <form onSubmit={onSubmit} className="space-y-2.5">
          <input
            className="field"
            placeholder="اسم التاجر"
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
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
          <select
            className="field"
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
          <input
            className="field"
            placeholder="العنوان"
            value={address}
            onChange={(e) => setAddress(e.target.value)}
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
          <div className="grid grid-cols-2 gap-2">
            <input
              className="field"
              placeholder="نسبة المصرف %"
              value={bankPercent}
              onChange={(e) => setBankPercent(e.target.value)}
              inputMode="decimal"
              required
            />
            <input
              className="field"
              placeholder="نسبة المنصة %"
              value={platformPercent}
              onChange={(e) => setPlatformPercent(e.target.value)}
              inputMode="decimal"
              required
            />
          </div>

          {editing ? (
            <label className="flex items-center gap-2 rounded-xl bg-[#F7FBFD] px-3 py-3 text-sm font-bold">
              <input
                type="checkbox"
                checked={active}
                onChange={(e) => setActive(e.target.checked)}
              />
              الحساب نشط
            </label>
          ) : null}

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
              {busy ? "جاري الحفظ..." : editing ? "حفظ التعديل" : "إضافة التاجر"}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
