"use client";

import Image from "next/image";
import type { AppUser, DashboardStats } from "@/lib/types";
import { StatsGrid } from "@/components/home/StatsGrid";

type Props = {
  open: boolean;
  user: AppUser | null;
  stats: DashboardStats | null;
  onClose: () => void;
  onLogout: () => void;
  variant?: "merchant" | "admin";
};

export function SideMenu({
  open,
  user,
  stats,
  onClose,
  onLogout,
  variant = "merchant",
}: Props) {
  return (
    <>
      <button
        type="button"
        className={`sheet-backdrop ${open ? "is-open" : ""}`}
        aria-label="إغلاق القائمة"
        onClick={onClose}
      />
      <aside className={`side-drawer ${open ? "is-open" : ""}`} aria-hidden={!open}>
        <div className="mb-4 flex items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <Image
              src="/images/Installment Planner App Icon.png"
              alt=""
              width={36}
              height={36}
              className="h-9 w-9 rounded-xl object-cover"
            />
            <div className="text-right">
              <div className="text-sm font-extrabold text-[var(--basic)]">القائمة</div>
              <div className="text-[11px] font-semibold text-[var(--basic)]/55">
                الإحصائيات والحساب
              </div>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="grid h-9 w-9 place-items-center rounded-xl bg-[#EAF6FB] text-[var(--basic)]"
            aria-label="إغلاق"
          >
            ✕
          </button>
        </div>

        <div className="mb-4 rounded-2xl bg-[#F3FAFD] p-3">
          <div className="flex items-center gap-2">
            <Image
              src="/icons/Faceless Corporate Real Estate Avatar.png"
              alt=""
              width={40}
              height={40}
              className="h-10 w-10 rounded-full object-cover"
            />
            <div className="min-w-0 text-right">
              <div className="truncate text-sm font-extrabold text-[var(--basic)]">
                {user?.full_name || "مستخدم"}
              </div>
              <div className="truncate text-xs font-semibold text-[var(--basic)]/55">
                {variant === "admin"
                  ? "مدير المنصة"
                  : user?.username || "—"}
              </div>
            </div>
          </div>
        </div>

        <h3 className="mb-2 text-sm font-extrabold text-[var(--basic)]">الإحصائيات</h3>
        <div className="side-stats mb-4 max-h-[58dvh] overflow-y-auto pe-1">
          <StatsGrid stats={stats} compact variant={variant} />
        </div>

        <button
          type="button"
          className="btn-primary w-full bg-[var(--late)]"
          onClick={onLogout}
        >
          تسجيل الخروج
        </button>
      </aside>
    </>
  );
}
