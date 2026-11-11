"use client";

type Props = {
  value: string;
  onChange: (value: string) => void;
  onSubmit?: () => void;
  placeholder?: string;
};

export function SearchBar({
  value,
  onChange,
  onSubmit,
  placeholder = "ابحث بالاسم أو رقم الهاتف",
}: Props) {
  const hasValue = value.trim().length > 0;

  return (
    <div className="search-shell">
      <label className="search-field">
        <span className="search-icon" aria-hidden>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none">
            <circle
              cx="11"
              cy="11"
              r="6.5"
              stroke="currentColor"
              strokeWidth="1.8"
            />
            <path
              d="M20 20L16.2 16.2"
              stroke="currentColor"
              strokeWidth="1.8"
              strokeLinecap="round"
            />
          </svg>
        </span>

        <input
          className="search-input"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") onSubmit?.();
          }}
          placeholder={placeholder}
          inputMode="search"
          aria-label={placeholder}
        />

        {hasValue ? (
          <button
            type="button"
            className="search-clear"
            aria-label="مسح البحث"
            onClick={() => onChange("")}
          >
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <path
                d="M3.5 3.5L10.5 10.5M10.5 3.5L3.5 10.5"
                stroke="currentColor"
                strokeWidth="1.7"
                strokeLinecap="round"
              />
            </svg>
          </button>
        ) : (
          <span className="search-hint">بحث</span>
        )}
      </label>
    </div>
  );
}
