"use client";

import Image from "next/image";
import type { AppUser } from "@/lib/types";

type Props = {
  user: AppUser | null;
  onMenu?: () => void;
};

export function MobileHeader({ user, onMenu }: Props) {
  return (
    <header className="header-curve">
      <div className="header-top" dir="ltr">
        <div className="header-row">
          <div className="user-chip" dir="rtl">
            <Image
              src="/icons/Faceless Corporate Real Estate Avatar.png"
              alt=""
              width={38}
              height={38}
              className="user-avatar"
            />
            <span className="user-meta">
              <span className="user-name">{user?.full_name || "مستخدم"}</span>
              <span className="user-handle">@{user?.username || "user"}</span>
            </span>
          </div>

          <div className="brand-block" dir="rtl">
            <Image
              src="/images/Installment Planner App Icon.png"
              alt="قسطلي"
              width={48}
              height={48}
              className="brand-icon"
              priority
            />
            <div className="brand-text">
              <div className="brand-title">قسطلي</div>
              <div className="brand-subtitle">نظام إدارة الأقساط</div>
            </div>
          </div>

          <button
            type="button"
            onClick={onMenu}
            aria-label="القائمة"
            className="menu-btn"
          >
            <span className="menu-lines">
              <span />
              <span />
              <span />
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
