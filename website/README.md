# قسطلي — موقع الموبايل

واجهة موبايل بـ Next.js + React + TypeScript مطابقة لتصميم الشاشة، ومتصلة بنفس API السيرفر.

## التشغيل

```bash
cd website
npm install
npm run dev
```

افتح [http://localhost:3000](http://localhost:3000)

## الإعداد

- `NEXT_PUBLIC_API_BASE_URL` في `.env.local` (افتراضي: `https://qasatly.compassaccuracy.com`)

## الميزات

- تسجيل دخول التاجر
- إحصائيات من `/api/dashboard`
- بحث وفلاتر من السيرفر
- قائمة زبائن ببطاقات الموبايل مع infinite scroll
- إضافة زبون جديد
