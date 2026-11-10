"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  clearSession,
  getCustomers,
  getDashboard,
  getStoredToken,
  getStoredUser,
  logout,
} from "@/lib/api";
import type { AppUser, Customer, DashboardStats } from "@/lib/types";
import { AddCustomerSheet } from "@/components/home/AddCustomerSheet";
import { CustomerCard } from "@/components/home/CustomerCard";
import { CustomerDetailSheet } from "@/components/home/CustomerDetailSheet";
import {
  FiltersSheet,
  type FiltersState,
} from "@/components/home/FiltersSheet";
import { MobileHeader } from "@/components/home/MobileHeader";
import { SearchBar } from "@/components/home/SearchBar";
import { SideMenu } from "@/components/home/SideMenu";

const PAGE_SIZE = 10;

const emptyFilters: FiltersState = {
  status: "",
  governorate: "",
  dateFrom: "",
  dateTo: "",
};

function matchesQuery(customer: Customer, q: string) {
  if (!q) return true;
  const needle = q.trim().toLowerCase();
  if (!needle) return true;
  return (
    customer.name.toLowerCase().includes(needle) ||
    customer.phone.includes(needle)
  );
}

export default function HomePage() {
  const router = useRouter();
  const [ready, setReady] = useState(false);
  const [user, setUser] = useState<AppUser | null>(null);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [customers, setCustomers] = useState<Customer[]>([]);
  const [page, setPage] = useState(1);
  const [pages, setPages] = useState(0);
  const [total, setTotal] = useState(0);
  const [queryInput, setQueryInput] = useState("");
  const [query, setQuery] = useState("");
  const [filters, setFilters] = useState<FiltersState>(emptyFilters);
  const [appliedFilters, setAppliedFilters] =
    useState<FiltersState>(emptyFilters);
  const [initialLoading, setInitialLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [filtersOpen, setFiltersOpen] = useState(false);
  const [addOpen, setAddOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [detailId, setDetailId] = useState<string | null>(null);

  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const loadingMoreRef = useRef(false);
  const requestIdRef = useRef(0);
  const appliedFiltersRef = useRef(appliedFilters);
  const queryRef = useRef(query);
  const hasLoadedOnce = useRef(false);

  appliedFiltersRef.current = appliedFilters;
  queryRef.current = query;

  const hasMore = page < pages;

  const visibleCustomers = useMemo(() => {
    const typed = queryInput.trim();
    // Immediate local filter by name/phone while waiting for server
    if (!typed) return customers;
    return customers.filter((c) => matchesQuery(c, typed));
  }, [customers, queryInput]);

  useEffect(() => {
    const token = getStoredToken();
    if (!token) {
      router.replace("/login");
      return;
    }
    setUser(getStoredUser());
    setReady(true);
  }, [router]);

  useEffect(() => {
    const t = setTimeout(() => setQuery(queryInput.trim()), 350);
    return () => clearTimeout(t);
  }, [queryInput]);

  const fetchCustomersPage = useCallback(
    async (nextPage: number, append: boolean, soft: boolean) => {
      const requestId = ++requestIdRef.current;
      const activeQuery = queryRef.current;
      const activeFilters = appliedFiltersRef.current;

      if (!append) {
        if (soft || hasLoadedOnce.current) setRefreshing(true);
        else setInitialLoading(true);
      }

      try {
        const result = await getCustomers({
          page: nextPage,
          page_size: PAGE_SIZE,
          q: activeQuery || undefined,
          status: activeFilters.status || undefined,
          governorate: activeFilters.governorate || undefined,
          date_from: activeFilters.dateFrom || undefined,
          date_to: activeFilters.dateTo || undefined,
        });

        // Ignore stale responses (older search/filter requests)
        if (requestId !== requestIdRef.current) return;

        setCustomers((prev) =>
          append ? [...prev, ...result.items] : result.items,
        );
        setPage(result.page);
        setPages(result.pages);
        setTotal(result.total);
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
    },
    [],
  );

  const loadDashboard = useCallback(async () => {
    const dash = await getDashboard();
    setStats(dash.stats);
  }, []);

  const refreshAll = useCallback(async () => {
    setError(null);
    try {
      await Promise.all([
        loadDashboard(),
        fetchCustomersPage(1, false, hasLoadedOnce.current),
      ]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "تعذر تحميل البيانات");
      setInitialLoading(false);
      setRefreshing(false);
    }
  }, [fetchCustomersPage, loadDashboard]);

  // First load
  useEffect(() => {
    if (!ready) return;
    void refreshAll();
  }, [ready]); // eslint-disable-line react-hooks/exhaustive-deps

  // Soft refresh on search / filters — keep current cards visible
  useEffect(() => {
    if (!ready || !hasLoadedOnce.current) return;
    void fetchCustomersPage(1, false, true);
  }, [ready, query, appliedFilters, fetchCustomersPage]);

  useEffect(() => {
    const node = sentinelRef.current;
    if (!node || !ready) return;

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
        void fetchCustomersPage(page + 1, true, true).finally(() => {
          loadingMoreRef.current = false;
          setLoadingMore(false);
        });
      },
      { rootMargin: "240px" },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, [
    fetchCustomersPage,
    hasMore,
    initialLoading,
    page,
    ready,
    refreshing,
  ]);

  const activeFiltersCount = useMemo(() => {
    let n = 0;
    if (appliedFilters.status) n += 1;
    if (appliedFilters.governorate) n += 1;
    if (appliedFilters.dateFrom || appliedFilters.dateTo) n += 1;
    return n;
  }, [appliedFilters]);

  async function onLogout() {
    await logout();
    clearSession();
    router.replace("/login");
  }

  if (!ready) {
    return (
      <main className="phone-shell grid place-items-center">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--soft)] border-t-transparent" />
      </main>
    );
  }

  const showEmpty =
    !initialLoading && visibleCustomers.length === 0;

  return (
    <main className="phone-shell pb-8">
      <MobileHeader
        user={user}
        onMenu={() => setMenuOpen(true)}
        onProfile={() => setMenuOpen(true)}
      />
      <SearchBar value={queryInput} onChange={setQueryInput} />

      <section className="mx-4 mt-5 flex items-center gap-2">
        <button
          type="button"
          className="btn-primary flex-1"
          onClick={() => setAddOpen(true)}
        >
          <span className="grid h-6 w-6 place-items-center rounded-full bg-white/20 text-lg leading-none">
            +
          </span>
          إضافة زبون جديد
        </button>
        <button
          type="button"
          className="btn-filter"
          onClick={() => {
            setFilters(appliedFilters);
            setFiltersOpen(true);
          }}
        >
          الفلاتر
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
            <path
              d="M4 6H20M7 12H17M10 18H14"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
            />
          </svg>
          {activeFiltersCount > 0 ? (
            <span className="grid h-5 min-w-5 place-items-center rounded-full bg-[var(--soft)] px-1 text-[10px] text-white">
              {activeFiltersCount}
            </span>
          ) : null}
        </button>
      </section>

      <section className="mx-4 mt-5">
        <div className="mb-3 flex items-center gap-2">
          <h2 className="text-[18px] font-extrabold text-[var(--basic)]">
            زبائن التاجر
          </h2>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="#069BAF">
            <path d="M16 11c1.7 0 3-1.3 3-3s-1.3-3-3-3-3 1.3-3 3 1.3 3 3 3zM8 11c1.7 0 3-1.3 3-3S9.7 5 8 5 5 6.3 5 8s1.3 3 3 3zm0 2c-2.7 0-8 1.3-8 4v2h10v-2c0-2.7-5.3-4-8-4zm8 0c-.3 0-.7 0-1 .1 1.2.8 2 2 2 3.9V19h7v-2c0-2.7-5.3-4-8-4z" />
          </svg>
          <span className="ms-auto text-xs font-bold text-[var(--basic)]/50">
            {refreshing
              ? "تحديث..."
              : `${
                  queryInput.trim() &&
                  visibleCustomers.length < customers.length
                    ? visibleCustomers.length
                    : total
                } زبون`}
          </span>
        </div>

        {error ? (
          <div className="rounded-2xl bg-white p-4 text-center text-sm font-bold text-[var(--late)]">
            {error}
            <button
              type="button"
              className="mt-2 block w-full text-[var(--soft)]"
              onClick={() => void refreshAll()}
            >
              إعادة المحاولة
            </button>
          </div>
        ) : null}

        <div
          className={`space-y-3 transition-opacity duration-200 ${
            refreshing ? "opacity-70" : "opacity-100"
          }`}
        >
          {visibleCustomers.map((c, i) => (
            <CustomerCard
              key={c.id}
              customer={c}
              index={i + 1}
              onOpen={(customer) => setDetailId(customer.id)}
            />
          ))}
          {showEmpty ? (
            <div className="rounded-2xl bg-white p-8 text-center text-sm font-bold text-[var(--basic)]/50">
              {query || activeFiltersCount > 0
                ? "لا توجد نتائج مطابقة"
                : "لا يوجد زبائن بعد"}
            </div>
          ) : null}
          <div ref={sentinelRef} className="h-8" />
          {initialLoading || loadingMore ? (
            <div className="py-3 text-center text-sm font-bold text-[var(--soft)]">
              جاري التحميل...
            </div>
          ) : null}
          {!hasMore && visibleCustomers.length > 0 && !refreshing ? (
            <div className="pb-2 text-center text-xs font-semibold text-[var(--basic)]/40">
              تم عرض كل النتائج (
              {queryInput.trim() && visibleCustomers.length < customers.length
                ? visibleCustomers.length
                : total}
              )
            </div>
          ) : null}
        </div>
      </section>

      <SideMenu
        open={menuOpen}
        user={user}
        stats={stats}
        onClose={() => setMenuOpen(false)}
        onLogout={() => void onLogout()}
      />

      <FiltersSheet
        open={filtersOpen}
        value={filters}
        onChange={setFilters}
        onClose={() => setFiltersOpen(false)}
        onReset={() => setFilters(emptyFilters)}
        onApply={() => {
          setAppliedFilters(filters);
          setFiltersOpen(false);
        }}
      />

      <AddCustomerSheet
        open={addOpen}
        onClose={() => setAddOpen(false)}
        onCreated={() => void refreshAll()}
      />

      <CustomerDetailSheet
        open={Boolean(detailId)}
        customerId={detailId}
        onClose={() => setDetailId(null)}
        onUpdated={() => void refreshAll()}
      />
    </main>
  );
}
