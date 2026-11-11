"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  approveCustomer,
  getCustomers,
  getDashboard,
  getMerchants,
  rejectCustomer,
} from "@/lib/api";
import type { AppUser, Customer, DashboardStats, Merchant } from "@/lib/types";
import { AddMerchantSheet } from "@/components/admin/AddMerchantSheet";
import { MerchantCard } from "@/components/admin/MerchantCard";
import { MerchantDetailSheet } from "@/components/admin/MerchantDetailSheet";
import { CustomerCard } from "@/components/home/CustomerCard";
import { CustomerDetailSheet } from "@/components/home/CustomerDetailSheet";
import { MobileHeader } from "@/components/home/MobileHeader";
import { SearchBar } from "@/components/home/SearchBar";
import { SideMenu } from "@/components/home/SideMenu";

type Tab = "merchants" | "customers" | "pending";

const PAGE_SIZE = 10;

type Props = {
  user: AppUser | null;
  onLogout: () => void;
};

export function AdminHome({ user, onLogout }: Props) {
  const [tab, setTab] = useState<Tab>("merchants");
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [pending, setPending] = useState<Customer[]>([]);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(0);
  const [total, setTotal] = useState(0);
  const [queryInput, setQueryInput] = useState("");
  const [query, setQuery] = useState("");
  const [initialLoading, setInitialLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const [addOpen, setAddOpen] = useState(false);
  const [detailId, setDetailId] = useState<string | null>(null);
  const [merchantDetailId, setMerchantDetailId] = useState<string | null>(null);
  const [actionBusy, setActionBusy] = useState<string | null>(null);

  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const loadingMoreRef = useRef(false);
  const requestIdRef = useRef(0);
  const tabRef = useRef(tab);
  const queryRef = useRef(query);
  const hasLoadedOnce = useRef(false);

  tabRef.current = tab;
  queryRef.current = query;

  const hasMore = page < pages;

  const items = useMemo(() => {
    if (tab === "merchants") return merchants;
    if (tab === "pending") return pending;
    return customers;
  }, [tab, merchants, pending, customers]);

  useEffect(() => {
    const t = setTimeout(() => setQuery(queryInput.trim()), 350);
    return () => clearTimeout(t);
  }, [queryInput]);

  const fetchTable = useCallback(async (nextPage: number, append: boolean) => {
    const requestId = ++requestIdRef.current;
    const activeTab = tabRef.current;
    const activeQuery = queryRef.current;

    if (!append) {
      if (hasLoadedOnce.current) setRefreshing(true);
      else setInitialLoading(true);
    }

    try {
      if (activeTab === "merchants") {
        const result = await getMerchants({
          page: nextPage,
          page_size: PAGE_SIZE,
          q: activeQuery || undefined,
        });
        if (requestId !== requestIdRef.current) return;
        setMerchants((prev) =>
          append ? [...prev, ...result.items] : result.items,
        );
        setPage(result.page);
        setPages(result.pages);
        setTotal(result.total);
      } else if (activeTab === "pending") {
        const result = await getCustomers({
          page: nextPage,
          page_size: PAGE_SIZE,
          q: activeQuery || undefined,
          status: "pending",
        });
        if (requestId !== requestIdRef.current) return;
        setPending((prev) =>
          append ? [...prev, ...result.items] : result.items,
        );
        setPage(result.page);
        setPages(result.pages);
        setTotal(result.total);
      } else {
        const result = await getCustomers({
          page: nextPage,
          page_size: PAGE_SIZE,
          q: activeQuery || undefined,
          exclude_pending: true,
        });
        if (requestId !== requestIdRef.current) return;
        setCustomers((prev) =>
          append ? [...prev, ...result.items] : result.items,
        );
        setPage(result.page);
        setPages(result.pages);
        setTotal(result.total);
      }
      setError(null);
      hasLoadedOnce.current = true;
    } catch (err) {
      if (requestId !== requestIdRef.current) return;
      setError(err instanceof Error ? err.message : "تعذر تحميل البيانات");
    } finally {
      if (requestId === requestIdRef.current) {
        setInitialLoading(false);
        setRefreshing(false);
      }
    }
  }, []);

  const refreshAll = useCallback(async () => {
    setError(null);
    try {
      const [dash] = await Promise.all([
        getDashboard(),
        fetchTable(1, false),
      ]);
      setStats(dash.stats);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل البيانات");
      setInitialLoading(false);
      setRefreshing(false);
    }
  }, [fetchTable]);

  useEffect(() => {
    void refreshAll();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!hasLoadedOnce.current) return;
    void fetchTable(1, false);
  }, [tab, query, fetchTable]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node) return;
    const observer = new IntersectionObserver(
      (entries) => {
        const hit = entries.some((e) => e.isIntersecting);
        if (
          !hit ||
          !hasMore ||
          loadingMoreRef.current ||
          initialLoading ||
          refreshing
        ) {
          return;
        }
        loadingMoreRef.current = true;
        setLoadingMore(true);
        void fetchTable(page + 1, true).finally(() => {
          loadingMoreRef.current = false;
          setLoadingMore(false);
        });
      },
      { rootMargin: "240px" },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, [fetchTable, hasMore, initialLoading, page, refreshing]);

  async function onApprove(customer: Customer) {
    setActionBusy(customer.id);
    try {
      await approveCustomer(customer.id);
      await refreshAll();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر اعتماد الخطة");
    } finally {
      setActionBusy(null);
    }
  }

  async function onReject(customer: Customer) {
    const ok = window.confirm(`رفض طلب خطة الزبون ${customer.name}؟`);
    if (!ok) return;
    setActionBusy(customer.id);
    try {
      await rejectCustomer(customer.id);
      await refreshAll();
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر رفض الطلب");
    } finally {
      setActionBusy(null);
    }
  }

  const title =
    tab === "merchants"
      ? "التجار المشتركين"
      : tab === "pending"
        ? "طلبات بانتظار الموافقة"
        : "زبائن التجار";

  return (
    <main className="phone-shell pb-8">
      <MobileHeader
        user={user}
        onMenu={() => setMenuOpen(true)}
        onProfile={() => setMenuOpen(true)}
        roleLabel="مدير المنصة"
      />
      <SearchBar
        value={queryInput}
        onChange={setQueryInput}
        placeholder={
          tab === "merchants"
            ? "ابحث عن تاجر بالاسم أو الهاتف"
            : "ابحث بالاسم أو رقم الهاتف"
        }
      />

      <section className="mx-4 mt-4 grid grid-cols-3 gap-2">
        {(
          [
            ["merchants", "التجار", stats?.merchants_count],
            ["customers", "الزبائن", stats?.total_customers],
            ["pending", "الطلبات", stats?.pending_count],
          ] as const
        ).map(([key, label, count]) => (
          <button
            key={key}
            type="button"
            className={`admin-tab ${tab === key ? "is-active" : ""}`}
            onClick={() => {
              setTab(key);
              setQueryInput("");
              setQuery("");
            }}
          >
            <span className="admin-tab-label">{label}</span>
            <span className="admin-tab-count">{count ?? "—"}</span>
          </button>
        ))}
      </section>

      <section className="mx-4 mt-5">
        <div className="mb-3 flex items-center gap-2">
          <h2 className="text-[17px] font-extrabold text-[var(--basic)]">
            {title}
          </h2>
          {tab === "pending" ? (
            <span className="rounded-full bg-[#F7EFDC] px-2.5 py-1 text-[11px] font-extrabold text-[#C38508]">
              {stats?.pending_count ?? total}
            </span>
          ) : null}
          <span className="ms-auto text-xs font-bold text-[var(--basic)]/50">
            {refreshing ? "تحديث..." : `${total}`}
          </span>
        </div>

        {tab === "merchants" ? (
          <button
            type="button"
            className="btn-primary mb-3 w-full"
            onClick={() => setAddOpen(true)}
          >
            <span className="grid h-6 w-6 place-items-center rounded-full bg-white/20 text-lg leading-none">
              +
            </span>
            إضافة تاجر
          </button>
        ) : null}

        {error ? (
          <div className="mb-3 rounded-2xl bg-white p-4 text-center text-sm font-bold text-[var(--late)]">
            {error}
            <button
              type="button"
              className="mt-2 block w-full text-[var(--soft)]"
              onClick={() => {
                if (
                  error.includes("جلسة") ||
                  error.includes("الدخول") ||
                  error.includes("صلاحية")
                ) {
                  window.location.replace("/login");
                  return;
                }
                void refreshAll();
              }}
            >
              {error.includes("جلسة") || error.includes("الدخول")
                ? "تسجيل الدخول"
                : "إعادة المحاولة"}
            </button>
          </div>
        ) : null}

        <div
          className={`space-y-3 transition-opacity duration-200 ${
            refreshing ? "opacity-70" : "opacity-100"
          }`}
        >
          {tab === "merchants"
            ? merchants.map((m, i) => (
                <MerchantCard
                  key={m.id}
                  merchant={m}
                  index={i + 1}
                  onOpen={(merchant) => setMerchantDetailId(merchant.id)}
                />
              ))
            : null}

          {tab === "customers"
            ? customers.map((c, i) => (
                <CustomerCard
                  key={c.id}
                  customer={c}
                  index={i + 1}
                  showMerchant
                  onOpen={(customer) => setDetailId(customer.id)}
                />
              ))
            : null}

          {tab === "pending"
            ? pending.map((c, i) => (
                <div key={c.id} className="space-y-2">
                  <CustomerCard
                    customer={c}
                    index={i + 1}
                    showMerchant
                    onOpen={(customer) => setDetailId(customer.id)}
                  />
                  <div className="grid grid-cols-2 gap-2 px-1">
                    <button
                      type="button"
                      className="h-11 rounded-xl bg-[#0E8A61] text-[13px] font-extrabold text-white disabled:opacity-60"
                      disabled={actionBusy === c.id}
                      onClick={() => void onApprove(c)}
                    >
                      اعتماد
                    </button>
                    <button
                      type="button"
                      className="h-11 rounded-xl border border-[#E7B4AE] bg-[#FDECEC] text-[13px] font-extrabold text-[var(--late)] disabled:opacity-60"
                      disabled={actionBusy === c.id}
                      onClick={() => void onReject(c)}
                    >
                      رفض
                    </button>
                  </div>
                </div>
              ))
            : null}

          {!initialLoading && !error && items.length === 0 ? (
            <div className="rounded-2xl bg-white p-8 text-center text-sm font-bold text-[var(--basic)]/50">
              لا توجد نتائج
            </div>
          ) : null}

          <div ref={sentinelRef} className="h-8" />
          {initialLoading || loadingMore ? (
            <div className="py-3 text-center text-sm font-bold text-[var(--soft)]">
              جاري التحميل...
            </div>
          ) : null}
        </div>
      </section>

      <SideMenu
        open={menuOpen}
        user={user}
        stats={stats}
        variant="admin"
        onClose={() => setMenuOpen(false)}
        onLogout={onLogout}
      />

      <AddMerchantSheet
        open={addOpen}
        onClose={() => setAddOpen(false)}
        onSaved={() => void refreshAll()}
      />

      <MerchantDetailSheet
        open={Boolean(merchantDetailId)}
        merchantId={merchantDetailId}
        onClose={() => setMerchantDetailId(null)}
        onUpdated={() => void refreshAll()}
      />

      <CustomerDetailSheet
        open={Boolean(detailId)}
        customerId={detailId}
        isAdmin
        onClose={() => setDetailId(null)}
        onUpdated={() => void refreshAll()}
      />
    </main>
  );
}
