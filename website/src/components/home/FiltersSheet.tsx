"use client";

import { iraqiGovernorates } from "@/lib/format";
import type { CustomerStatus } from "@/lib/types";

export type FiltersState = {
  status: CustomerStatus | "";
  governorate: string;
  dateFrom: string;
  dateTo: string;
};

type Props = {
  open: boolean;
  value: FiltersState;
  onChange: (next: FiltersState) => void;
  onApply: () => void;
  onClose: () => void;
  onReset: () => void;
};

export function FiltersSheet({
  open,
  value,
  onChange,
  onApply,
  onClose,
  onReset,
}: Props) {
  if (!open) return null;

  return (
    <>
      <button
        type="button"
        className="sheet-backdrop is-open"
        aria-label="إغلاق"
        onClick={onClose}
      />
      <div className="center-dialog" role="dialog" aria-modal="true">
        <div className="mb-3 flex items-center justify-between gap-2">
          <h3 className="text-base font-extrabold text-[var(--basic)]">
            الفلاتر
          </h3>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onReset}
              className="text-xs font-bold text-[var(--soft)]"
            >
              إعادة ضبط
            </button>
            <button
              type="button"
              onClick={onClose}
              className="grid h-8 w-8 place-items-center rounded-xl bg-[#EAF6FB] text-sm font-bold text-[var(--basic)]"
              aria-label="إغلاق"
            >
              ✕
            </button>
          </div>
        </div>

        <label className="mb-1.5 block text-xs font-bold text-[var(--basic)]/75">
          حالة الخطة
        </label>
        <select
          className="field mb-2.5"
          value={value.status}
          onChange={(e) =>
            onChange({
              ...value,
              status: e.target.value as FiltersState["status"],
            })
          }
        >
          <option value="">الكل</option>
          <option value="active">نشطة</option>
          <option value="inactive">غير نشطة</option>
          <option value="completed">مكتملة</option>
          <option value="pending">بانتظار الموافقة</option>
          <option value="rejected">مرفوضة</option>
        </select>

        <label className="mb-1.5 block text-xs font-bold text-[var(--basic)]/75">
          المحافظة
        </label>
        <select
          className="field mb-2.5"
          value={value.governorate}
          onChange={(e) =>
            onChange({ ...value, governorate: e.target.value })
          }
        >
          <option value="">الكل</option>
          {iraqiGovernorates.map((g) => (
            <option key={g} value={g}>
              {g}
            </option>
          ))}
        </select>

        <div className="mb-3 grid grid-cols-2 gap-2.5">
          <div>
            <label className="mb-1.5 block text-xs font-bold text-[var(--basic)]/75">
              من تاريخ
            </label>
            <input
              type="date"
              className="field"
              value={value.dateFrom}
              onChange={(e) =>
                onChange({ ...value, dateFrom: e.target.value })
              }
            />
          </div>
          <div>
            <label className="mb-1.5 block text-xs font-bold text-[var(--basic)]/75">
              إلى تاريخ
            </label>
            <input
              type="date"
              className="field"
              value={value.dateTo}
              onChange={(e) => onChange({ ...value, dateTo: e.target.value })}
            />
          </div>
        </div>

        <div className="grid grid-cols-2 gap-2">
          <button
            type="button"
            className="btn-filter w-full justify-center"
            onClick={onClose}
          >
            إلغاء
          </button>
          <button
            type="button"
            className="btn-primary w-full"
            onClick={onApply}
          >
            تطبيق
          </button>
        </div>
      </div>
    </>
  );
}
