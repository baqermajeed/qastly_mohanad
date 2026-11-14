import Image from "next/image";
import { money } from "@/lib/format";
import type { DashboardStats } from "@/lib/types";

type Props = {
  stats: DashboardStats | null;
  compact?: boolean;
  variant?: "merchant" | "admin" | "investor";
  investorDueAmount?: number | null;
  investorDueSubtitle?: string | null;
  onPickInvestorDueMonth?: () => void;
};

function StatCard({
  title,
  value,
  tone = "white",
  compact = false,
  subtitle,
  onIconClick,
  iconButtonLabel,
}: {
  title: string;
  value: string;
  tone?: "white" | "mint" | "gold" | "navy";
  compact?: boolean;
  subtitle?: string | null;
  onIconClick?: () => void;
  iconButtonLabel?: string;
}) {
  const bg =
    tone === "mint"
      ? "bg-[#D2E9E6]"
      : tone === "gold"
        ? "bg-[#F7EFDC]"
        : tone === "navy"
          ? "bg-[#DCE8F1]"
          : "bg-white";

  const icon = onIconClick ? (
    <button
      type="button"
      onClick={onIconClick}
      aria-label={iconButtonLabel || "اختيار الشهر"}
      title={iconButtonLabel || "اختيار الشهر"}
      className="grid h-8 w-8 place-items-center rounded-[12px] bg-[rgba(6,155,175,0.18)] text-[var(--soft)] transition hover:bg-[rgba(6,155,175,0.28)]"
    >
      <svg
        width={compact ? 16 : 18}
        height={compact ? 16 : 18}
        viewBox="0 0 24 24"
        fill="none"
        aria-hidden
      >
        <path
          d="M7 3v2M17 3v2M4.5 9h15M6 5h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Z"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        <path
          d="M8.5 13h.01M12 13h.01M15.5 13h.01M8.5 16.5h.01M12 16.5h.01"
          stroke="currentColor"
          strokeWidth="2.4"
          strokeLinecap="round"
        />
      </svg>
    </button>
  ) : (
    <Image
      src="/images/stat_icon.png"
      alt=""
      width={compact ? 18 : 22}
      height={compact ? 18 : 22}
      className="opacity-90"
    />
  );

  return (
    <div className={`stat-card ${bg} ${compact ? "p-3" : ""}`}>
      <div className="mb-2 flex items-center justify-between gap-2">
        <div className="min-w-0">
          <span className="block text-[12px] font-bold text-[var(--basic)]/70">
            {title}
          </span>
          {subtitle ? (
            <span className="mt-0.5 block text-[10px] font-bold text-[var(--soft)]">
              {subtitle}
            </span>
          ) : null}
        </div>
        {icon}
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
  investorDueAmount = null,
  investorDueSubtitle = null,
  onPickInvestorDueMonth,
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

  const dueValue =
    investorDueAmount != null
      ? investorDueAmount
      : (stats.investor_due_this_month_amount ?? 0);

  type Item = {
    title: string;
    value: string;
    tone: "white" | "mint" | "gold" | "navy";
    subtitle?: string | null;
    onIconClick?: () => void;
    iconButtonLabel?: string;
  };

  const items: Item[] =
    variant === "investor"
      ? [
          {
            title: "أصل الرصيد",
            value: money(stats.investor_principal_total ?? stats.total_amounts),
            tone: "navy",
          },
          {
            title: "بعد الفائدة",
            value: money(
              stats.investor_total_with_interest ?? stats.financed_amounts,
            ),
            tone: "mint",
          },
          {
            title: "مستحقاتك هذا الشهر",
            value: money(dueValue),
            tone: "gold",
            subtitle: investorDueSubtitle,
            onIconClick: onPickInvestorDueMonth,
            iconButtonLabel: "اختيار شهر",
          },
          {
            title: "المبالغ المستلمة (كل العقود)",
            value: money(stats.investor_paid_amount ?? stats.paid_amounts),
            tone: "mint",
          },
          {
            title: "المبالغ المتبقية (كل العقود)",
            value: money(
              stats.investor_remaining_amount ?? stats.remaining_amounts,
            ),
            tone: "gold",
          },
        ]
      : variant === "admin"
        ? [
            {
              title: "عدد التجار",
              value: `${stats.merchants_count}`,
              tone: "navy",
            },
            {
              title: "عدد الخطط",
              value: `${stats.total_customers}`,
              tone: "mint",
            },
            {
              title: "مستحقات التجار هذا الشهر",
              value: money(stats.due_this_month_amount ?? 0),
              tone: "gold",
            },
            {
              title: "أرباح المنصة هذا الشهر",
              value: money(stats.platform_amounts_this_month ?? 0),
              tone: "mint",
            },
            {
              title: "عدد المستثمرين",
              value: `${stats.investors_count ?? 0}`,
              tone: "navy",
            },
            {
              title: "عدد العقود الاستثمارية",
              value: `${stats.investments_count ?? 0}`,
              tone: "mint",
            },
            {
              title: "مستحقات المستثمرين هذا الشهر",
              value: money(stats.investor_due_this_month_amount ?? 0),
              tone: "gold",
            },
          ]
        : [
            {
              title: "اجمالي المبالغ",
              value: money(stats.total_amounts),
              tone: "navy",
            },
            {
              title: "اجمالي المبالغ بعد النسب",
              value: money(stats.financed_amounts),
              tone: "white",
            },
            {
              title: "مستحقاتك",
              value: money(stats.due_this_month_amount ?? 0),
              tone: "gold",
            },
            {
              title: "عدد الزبائن",
              value: `${stats.total_customers} زبون`,
              tone: "navy",
            },
            {
              title: "الخطط النشطة",
              value: `${stats.remaining_count}`,
              tone: "white",
            },
          ];

  const renderCards = (list: Item[], colsClass: string) => (
    <div className={colsClass}>
      {list.map((item) => (
        <StatCard
          key={item.title}
          title={item.title}
          value={item.value}
          tone={item.tone}
          subtitle={item.subtitle}
          onIconClick={item.onIconClick}
          iconButtonLabel={item.iconButtonLabel}
          compact={compact}
        />
      ))}
    </div>
  );

  if (compact) {
    return (
      <div className="grid grid-cols-1 gap-2">
        {items.map((item) => (
          <StatCard
            key={item.title}
            title={item.title}
            value={item.value}
            tone={item.tone}
            subtitle={item.subtitle}
            onIconClick={item.onIconClick}
            iconButtonLabel={item.iconButtonLabel}
            compact
          />
        ))}
      </div>
    );
  }

  if (variant === "admin") {
    const merchants = items.slice(0, 4);
    const investors = items.slice(4);
    return (
      <div className="mx-4 mt-4 space-y-4">
        <section className="space-y-2">
          <h3 className="text-[14px] font-extrabold text-[var(--basic)]">
            إحصائيات التجار
          </h3>
          {renderCards(
            merchants,
            "grid grid-cols-2 gap-2 sm:grid-cols-4",
          )}
        </section>
        <section className="space-y-2">
          <h3 className="text-[14px] font-extrabold text-[var(--basic)]">
            إحصائيات المستثمرين
          </h3>
          {renderCards(
            investors,
            "grid grid-cols-1 gap-2 sm:grid-cols-3",
          )}
        </section>
      </div>
    );
  }

  return (
    <div className="mx-4 mt-4 space-y-2">
      {renderCards(
        items,
        "grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-5",
      )}
    </div>
  );
}
