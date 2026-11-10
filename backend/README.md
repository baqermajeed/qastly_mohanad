# Qasatly Mohanad Backend (FastAPI + MongoDB)

## التشغيل

1. شغّل MongoDB محلياً أو استخدم MongoDB Atlas وضع الرابط في `.env`
2. من مجلد `backend`:

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Docs: http://127.0.0.1:8000/docs
- Health: http://127.0.0.1:8000/health
- Database: `qasatly_mohanad`

## أهم الـ Endpoints

- `GET /api/dashboard` — إحصائيات + قائمة الزبائن
- `POST /api/customers` — إضافة زبون
- `GET /api/customers/{id}` — ملف الزبون + سجل الدفعات
- `POST /api/payments` — تسديد دفعة
- `GET /api/customers?status=late` — المتأخرون
