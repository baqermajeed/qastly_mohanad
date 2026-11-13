"use client";

import Image from "next/image";
import { money } from "@/lib/format";
import type { Investor } from "@/lib/types";

type Props = {
  investor: Investor;
  index: number;
  onOpen?: (investor: Investor) => void;
};

export function InvestorCard({ investor, index, onOpen }: Props) {
  const whatsapp = investor.phone
    ? `https://wa.me/964${investor.phone.replace(/^0/, "")}`
    : null;

  return (
    <article
      className="customer-card cursor-pointer transition active:scale-[0.99]"
      role="button"
      tabIndex={0}
      onClick={() => onOpen?.(investor)}
      onKeyDown={(e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          onOpen?.(investor);
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
            {investor.full_name}
          </h3>
          <div className="mt-0.5 text-[12px] font-bold text-[var(--basic)]/50">
            @{investor.username}
          </div>
          <div className="mt-1 text-[12px] font-bold text-[#1E7AA8]">
            {investor.phone || "—"}
            {investor.master_card
              ? ` · ماستر ${investor.master_card}`
              : ""}
          </div>
        </div>
        <div className="flex flex-col items-end gap-2">
          <span
            className={`status-pill ${investor.active ? "" : "opacity-70"}`}
            style={
              investor.active
                ? undefined
                : { background: "#FDECEC", color: "#C0392B" }
            }
          >
            {investor.active ? "نشط" : "موقوف"}
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

      <div className="grid grid-cols-2 gap-2 rounded-2xl bg-[#F7FBFD] px-2 py-3 text-center sm:grid-cols-4">
        <div>
          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
            العقود
          </div>
          <div className="text-[13px] font-extrabold text-[var(--basic)]">
            {investor.investments_count}
          </div>
        </div>
        <div>
          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
            الأصل
          </div>
          <div className="text-[13px] font-extrabold text-[var(--basic)]">
            {money(investor.principal_total)}
          </div>
        </div>
        <div>
          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
            المستلم
          </div>
          <div className="text-[13px] font-extrabold text-[#0E8A61]">
            {money(investor.paid_amount)}
          </div>
        </div>
        <div>
          <div className="mb-1 text-[11px] font-bold text-[var(--basic)]/55">
            المتبقي
          </div>
          <div className="text-[13px] font-extrabold text-[#C38508]">
            {money(investor.remaining_amount)}
          </div>
        </div>
      </div>
    </article>
  );
}
