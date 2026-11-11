"use client";

import Image from "next/image";
import { money } from "@/lib/format";
import type { Merchant } from "@/lib/types";

type Props = {
  merchant: Merchant;
  index: number;
  onOpen?: (merchant: Merchant) => void;
};

export function MerchantCard({ merchant, index, onOpen }: Props) {
  const whatsapp = merchant.phone
    ? `https://wa.me/964${merchant.phone.replace(/^0/, "")}`
    : null;
  const unpaid =
    !merchant.due_confirmed_this_month &&
    (merchant.due_this_month_amount ?? 0) > 0;

  return (
    <article
      className="customer-card cursor-pointer transition active:scale-[0.99]"
      role="button"
      tabIndex={0}
      onClick={() => onOpen?.(merchant)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpen?.(merchant);
        }
      }}
    >
      <div className="mb-3 flex items-start gap-2">
        <div className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-[#E3F4FB] text-[12px] font-extrabold text-[var(--soft)]">
          {String(index).padStart(2, "0")}
        </div>
        <Image
          src="/icons/Faceless Corporate Real Estate Avatar.png"
          alt=""
          width={42}
          height={42}
          className="h-[42px] w-[42px] rounded-full object-cover"
        />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-1.5">
            <h3 className="truncate text-[15px] font-extrabold text-[var(--basic)]">
              {merchant.full_name}
            </h3>
            {unpaid ? (
              <span className="shrink-0 rounded-lg border border-[#E53935]/35 bg-[#FDECEC] px-1.5 py-0.5 text-[10px] font-extrabold text-[#E53935]">
                غير مسدد
              </span>
            ) : null}
          </div>
          <div className="mt-0.5 text-[12px] font-bold text-[var(--basic)]/50">
            @{merchant.username}
          </div>
          <div className="mt-1 text-[12px] font-bold text-[#1E7AA8]">
            {merchant.phone || "—"} · {merchant.governorate || "—"}
          </div>
        </div>
        <div className="flex flex-col items-end gap-2">
          <span
            className={`status-pill ${merchant.active ? "" : "opacity-70"}`}
            style={
              merchant.active
                ? undefined
                : { background: "#FDECEC", color: "#C0392B" }
            }
          >
            {merchant.active ? "نشط" : "موقوف"}
          </span>
          {whatsapp ? (
            <a
              className="whatsapp-pill"
              href={whatsapp}
              target="_blank"
              rel="noreferrer"
              onClick={(e) => e.stopPropagation()}
            >
              واتساب
            </a>
          ) : null}
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 rounded-2xl bg-[#F7FBFD] px-2 py-3 text-center">
        <div>
          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
            الزبائن
          </div>
          <div className="text-[13px] font-extrabold text-[var(--basic)]">
            {merchant.customers_count}
          </div>
        </div>
        <div>
          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
            عمولة المنصة
          </div>
          <div className="text-[13px] font-extrabold text-[var(--basic)]">
            {money(merchant.platform_amounts)}
          </div>
        </div>
        <div>
          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
            النسب
          </div>
          <div className="text-[12px] font-extrabold text-[var(--basic)]">
            {merchant.bank_percent}% / {merchant.platform_percent}%
          </div>
        </div>
      </div>
    </article>
  );
}
