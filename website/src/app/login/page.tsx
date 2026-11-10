"use client";

import Image from "next/image";
import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { getStoredToken, login } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [obscure, setObscure] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (getStoredToken()) router.replace("/home");
  }, [router]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      await login(username.trim(), password);
      router.replace("/home");
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : "تعذر الاتصال بالخادم، حاول مرة أخرى",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="phone-shell flex items-center justify-center px-4 py-8">
      <form
        onSubmit={onSubmit}
        className="w-full rounded-[24px] bg-[#DFF3F8] p-7 shadow-[0_16px_40px_rgba(6,155,175,0.25)]"
      >
        <div className="mb-5 flex justify-center">
          <Image
            src="/images/Installment Planner App Icon.png"
            alt="قسطلي"
            width={72}
            height={72}
            className="rounded-[18px] object-cover"
            priority
          />
        </div>
        <h1 className="mb-6 text-center text-2xl font-extrabold text-[var(--basic)]">
          تسجيل الدخول
        </h1>

        <label className="mb-2 block text-sm font-bold">اسم المستخدم</label>
        <input
          className="field mb-4 bg-white"
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          autoComplete="username"
          required
        />

        <label className="mb-2 block text-sm font-bold">كلمة المرور</label>
        <div className="relative mb-4">
          <input
            className="field bg-white pe-12"
            type={obscure ? "password" : "text"}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            required
          />
          <button
            type="button"
            className="absolute start-3 top-1/2 -translate-y-1/2 text-sm font-bold text-[var(--basic)]/50"
            onClick={() => setObscure((v) => !v)}
          >
            {obscure ? "إظهار" : "إخفاء"}
          </button>
        </div>

        {error ? (
          <p className="mb-3 text-center text-sm font-bold text-[var(--late)]">
            {error}
          </p>
        ) : null}

        <button type="submit" className="btn-primary w-full" disabled={busy}>
          {busy ? "جاري الدخول..." : "دخول"}
        </button>
      </form>
    </main>
  );
}
