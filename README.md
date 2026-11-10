# قساطي مهند (qasatly_mohanad)

**Flutter + FastAPI + MongoDB**

## هيكل المشروع

```
qasatly_mohanad/
  frontend/   # تطبيق Flutter
  backend/    # FastAPI + MongoDB
```

## تشغيل الباكند

1. ثبّت/شغّل MongoDB محلياً أو ضع رابط Atlas في `backend/.env`
2. نفّذ:

```bash
cd backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Docs: http://127.0.0.1:8000/docs

> قاعدة البيانات المستخدمة: `qasatly_mohanad` (منفصلة عن أي مشروع سابق)

## تشغيل الفرونت

```bash
cd frontend
flutter pub get
flutter run -d windows
```

للمحاكي أندرويد غيّر عنوان الـ API في:

`frontend/lib/core/constants.dart`

إلى `http://10.0.2.2:8000`

أو شغّل:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## الميزات الحالية

- إضافة زبون (اسم، هاتف، محافظة، مبلغ، أشهر، تاريخ)
- ملف زبون + سجل دفعات
- تسديد دفعة
- إحصائيات الصفحة الرئيسية
- قائمة المتأخرين مع زر واتساب
- جدول/قائمة كل الزبائن مع الحالة
