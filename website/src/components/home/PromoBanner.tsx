"use client";

import Image from "next/image";

type Props = {
  title?: string;
  subtitle?: string;
};

export function PromoBanner({
  title = "مرحبا بك في نظام قسطلي💸",
  subtitle = "أضف زبائنك وخطط أقساطهم، ومستحقاتك نقدية فورية بعد النسب",
}: Props) {
  return (
    <section className="relative mx-4 mt-4 h-[140px] overflow-hidden rounded-2xl">
      <Image
        src="/images/Dynamic Finance Dashboard Banner.png"
        alt=""
        fill
        className="object-cover object-center"
        priority
      />
      <div className="absolute inset-0 bg-gradient-to-l from-[#0B3A5C]/55 to-transparent" />
      <div className="absolute inset-y-0 right-0 flex w-[75%] flex-col justify-center px-4 text-right">
        <p className="text-[16px] font-extrabold leading-snug text-white drop-shadow">
          {title}
        </p>
        <p className="mt-2 text-[12px] font-semibold leading-relaxed text-white/95 drop-shadow">
          {subtitle}
        </p>
      </div>
      <div className="absolute bottom-2 left-0 right-0 flex justify-center">
        <Image
          src="/icons/banner_indicators.svg"
          alt=""
          width={59}
          height={17}
        />
      </div>
    </section>
  );
}
