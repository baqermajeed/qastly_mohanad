"use client";

import { FormEvent, useState } from "react";
import { createMerchant } from "@/lib/api";
import { iraqiGovernorates } from "@/lib/format";

type Props = {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
};

export function AddMerchantSheet({ open, onClose, onCreated }: Props) {
  const [fullName, setFullName] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");
  const [governorate, setGovernorate] = useState("");
  const [address, setAddress] = useState("");
  const [masterCard, setMasterCard] = useState("");
  const [bankPercent, setBankPercent] = useState("10");
  const [platformPercent, setPlatformPercent] = useState("5");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

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

    setBusy(true);
    try {
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
      setFullName("");
      setUsername("");
      setPassword("");
      setPhone("");
      setGovernorate("");
      setAddress("");
      setMasterCard("");
      setBankPercent("10");
      setPlatformPercent("5");
      onCreated();
      onClose();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر إضافة التاجر");
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
        className="center-dialog max-h-[88dvh] w-[min(calc(100%-28px),400px)]"
        role="dialog"
        aria-modal="true"
      >
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="text-base font-extrabold text-[var(--basic)]">
            إضافة تاجر
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
          />
          <input
            className="field"
            placeholder="كلمة المرور"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            minLength={4}
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
              {busy ? "جاري الحفظ..." : "إضافة التاجر"}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
