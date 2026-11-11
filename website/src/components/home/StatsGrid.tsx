import Image from "next/image";
import { money } from "@/lib/format";
import type { DashboardStats } from "@/lib/types";

type Props = {
  stats: DashboardStats | null;
  compact?: boolean;
  variant?: "merchant" | "admin";
};

function StatCard({
  title,
  value,
  tone = "white",
  compact = false,
}: {
  title: string;
  value: string;
  tone?: "white" | "mint" | "gold" | "navy";
  compact?: boolean;
}) {
  const bg =
    tone === "mint"
      ? "bg-[#D2E9E6]"
      : tone === "gold"
        ? "bg-[#F7EFDC]"
        : tone === "navy"
          ? "bg-[#DCE8F1]"
          : "bg-white";

  return (
    <div className={`stat-card ${bg} ${compact ? "p-3" : ""}`}>
      <div className="mb-2 flex items-center justify-between gap-2">
        <span className="text-[12px] font-bold text-[var(--basic)]/70">
          {title}
        </span>
        <Image
          src="/images/stat_icon.png"
          alt=""
          width={compact ? 18 : 22}
          height={compact ? 18 : 22}
          className="opacity-90"
        />
      </div>
      <div
        className={`${compact ? "text-[15px]" : "text-[17px]"} font-extrabold text-[var(--basic)]`}
      >
        {value}
      </div>
    </div>
  );
}

export function StatsGrid({
  stats,
  compact = false,
  variant = "merchant",
}: Props) {
  if (!stats) {
    return (
      <div
        className={`${compact ? "" : "mx-4 mt-4"} grid animate-pulse grid-cols-1 gap-2`}
      >
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="h-[68px] rounded-2xl bg-white/70" />
        ))}
      </div>
    );
  }

  const items =
    variant === "admin"
      ? [
          {
            title: "المبالغ الواجب تسديدها هذا الشهر",
            value: money(stats.due_this_month_amount ?? 0),
            tone: "gold" as const,
          },
          {
            title: "عمولة المنصة",
            value: money(stats.platform_amounts),
            tone: "navy" as const,
          },
          {
            title: "عمولة المصرف",
            value: money(stats.bank_amounts),
            tone: "gold" as const,
          },
          {
            title: "إجمالي الخطط",
            value: money(stats.total_amounts),
            tone: "mint" as const,
          },
          {
            title: "المتبقي على الزبائن",
            value: money(stats.remaining_amounts),
            tone: "gold" as const,
          },
          {
            title: "عدد التجار",
            value: `${stats.merchants_count}`,
            tone: "navy" as const,
          },
          {
            title: "عدد الزبائن",
            value: `${stats.total_customers}`,
            tone: "mint" as const,
          },
          {
            title: "طلبات بانتظار الموافقة",
            value: `${stats.pending_count}`,
            tone: "gold" as const,
          },
          {
            title: "الخطط النشطة",
            value: `${stats.remaining_count}`,
            tone: "white" as const,
          },
        ]
      : [
          {
            title: "إجمالي المبالغ",
            value: money(stats.total_amounts),
            tone: "navy" as const,
          },
          {
            title: "المبالغ المسددة",
            value: money(stats.paid_amounts),
            tone: "mint" as const,
          },
          {
            title: "المبالغ المتبقية",
            value: money(stats.remaining_amounts),
            tone: "gold" as const,
          },
          {
            title: "عدد الزبائن",
            value: `${stats.total_customers}`,
            tone: "navy" as const,
          },
          {
            title: "عمولة المنصة",
            value: money(stats.platform_amounts),
            tone: "mint" as const,
          },
          {
            title: "عمولة المصرف",
            value: money(stats.bank_amounts),
            tone: "gold" as const,
          },
          {
            title: "الخطط النشطة",
            value: `${stats.remaining_count}`,
            tone: "white" as const,
          },
          {
            title: "مستحقاتك هذا الشهر",
            value: money(stats.due_this_month_amount ?? 0),
            tone: "gold" as const,
          },
        ];

  if (compact) {
    return (
      <div className="grid grid-cols-1 gap-2">
        {items.map((item) => (
          <StatCard
            key={item.title}
            title={item.title}
            value={item.value}
            tone={item.tone}
            compact
          />
        ))}
      </div>
    );
  }

  return (
    <div className="mx-4 mt-4 space-y-2">
      <div className="grid grid-cols-2 gap-2">
        {items.slice(0, 2).map((item) => (
          <StatCard
            key={item.title}
            title={item.title}
            value={item.value}
            tone={item.tone}
          />
        ))}
      </div>
      <div className="grid grid-cols-3 gap-2">
        {items.slice(2, 5).map((item) => (
          <StatCard
            key={item.title}
            title={item.title}
            value={item.value}
            tone={item.tone}
          />
        ))}
      </div>
      <div className="grid grid-cols-3 gap-2">
        {items.slice(5).map((item) => (
          <StatCard
            key={item.title}
            title={item.title}
            value={item.value}
            tone={item.tone}
          />
        ))}
      </div>
    </div>
  );
}
