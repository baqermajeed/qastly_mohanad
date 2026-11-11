"use client";

import Image from "next/image";
import { money, statusLabel } from "@/lib/format";
import type { Customer } from "@/lib/types";

type Props = {
  customer: Customer;
  index: number;
  onOpen?: (customer: Customer) => void;
  showMerchant?: boolean;
};

function MoneyCell({
  label,
  value,
  icon,
}: {
  label: string;
  value: string;
  icon: "total" | "remain" | "month";
}) {
  const iconSrc =
    icon === "remain"
      ? "/images/Calendar, Coins, and Alert Badge.png"
      : icon === "month"
        ? "/images/Calendar, Credit Card, and Gold Coins.png"
        : "/images/stat_icon.png";

  return (
    <div className="text-center">
      <div className="mb-1 flex items-center justify-center gap-1 text-[11px] font-bold text-[var(--basic)]/55">
        <Image src={iconSrc} alt="" width={16} height={16} />
        <span>{label}</span>
      </div>
      <div className="text-[13px] font-extrabold text-[var(--basic)]">
        {value}
      </div>
    </div>
  );
}

export function CustomerCard({
  customer,
  index,
  onOpen,
  showMerchant = false,
}: Props) {
  return (
    <article
      className="customer-card cursor-pointer transition active:scale-[0.99]"
      role="button"
      tabIndex={0}
      onClick={() => onOpen?.(customer)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpen?.(customer);
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
          <h3 className="truncate text-[15px] font-extrabold text-[var(--basic)]">
            {customer.name}
          </h3>
          {showMerchant && customer.merchant_name ? (
            <div className="mt-0.5 truncate text-[11px] font-bold text-[var(--basic)]/45">
              التاجر: {customer.merchant_name}
            </div>
          ) : null}
          <a
            href={`tel:${customer.phone}`}
            className="mt-0.5 inline-flex items-center gap-1 text-[12px] font-bold text-[#1E7AA8]"
            onClick={(e) => e.stopPropagation()}
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
              <path d="M6.6 10.8c1.4 2.8 3.8 5.1 6.6 6.6l2.2-2.2c.3-.3.7-.4 1.1-.2 1.2.4 2.5.6 3.8.6.6 0 1 .4 1 1V20c0 .6-.4 1-1 1C10.6 21 3 13.4 3 4c0-.6.4-1 1-1h3.5c.6 0 1 .4 1 1 0 1.3.2 2.6.6 3.8.1.4 0 .8-.3 1.1L6.6 10.8z" />
            </svg>
            {customer.phone}
          </a>
        </div>
        <div className="flex flex-col items-end gap-2">
          <span className="status-pill">{statusLabel(customer.status)}</span>
          <a
            className="whatsapp-pill"
            href={customer.whatsapp_url}
            target="_blank"
            rel="noreferrer"
            onClick={(e) => e.stopPropagation()}
          >
            واتساب
            <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2a10 10 0 0 0-8.7 14.9L2 22l5.3-1.4A10 10 0 1 0 12 2zm0 18a8 8 0 0 1-4.1-1.1l-.3-.2-3.1.8.8-3-.2-.3A8 8 0 1 1 12 20zm4.4-5.9c-.2-.1-1.4-.7-1.6-.8s-.4-.1-.5.1-.6.8-.7.9-.3.2-.5.1a6.5 6.5 0 0 1-1.9-1.2 7.2 7.2 0 0 1-1.3-1.6c-.1-.2 0-.4.1-.5l.4-.5.1-.3c0-.1 0-.3-.1-.4s-.5-1.2-.7-1.6c-.2-.4-.4-.4-.5-.4h-.5c-.2 0-.4.1-.6.3s-.8.8-.8 1.9.8 2.2.9 2.3a8.8 8.8 0 0 0 3.4 2.7c2.1.8 2.1.5 2.5.5s1.2-.5 1.3-1 .2-.9.1-1z" />
            </svg>
          </a>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-2 rounded-2xl bg-[#F7FBFD] px-2 py-3">
        <MoneyCell
          label="المبلغ الكلي"
          value={money(customer.total_amount)}
          icon="total"
        />
        <MoneyCell
          label="المبلغ المتبقي"
          value={money(customer.remaining_amount)}
          icon="remain"
        />
        <MoneyCell
          label="الدفعة الشهرية"
          value={money(customer.monthly_payment)}
          icon="month"
        />
      </div>
    </article>
  );
}
