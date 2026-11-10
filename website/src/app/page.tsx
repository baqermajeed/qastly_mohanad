"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { getStoredToken } from "@/lib/api";

export default function RootPage() {
  const router = useRouter();

  useEffect(() => {
    router.replace(getStoredToken() ? "/home" : "/login");
  }, [router]);

  return (
    <main className="phone-shell grid place-items-center">
      <div className="h-8 w-8 animate-spin rounded-full border-2 border-[var(--soft)] border-t-transparent" />
    </main>
  );
}
