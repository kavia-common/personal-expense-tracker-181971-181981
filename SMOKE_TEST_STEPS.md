# Smoke Test Steps

Pre-req
1) Start DB (port 5001)
   - cd personal-expense-tracker-181971-181981/expense_tracker_database
   - ./startup.sh
2) Start Backend (port 3001)
   - cd personal-expense-tracker-181971-181980/expense_tracker_backend
   - export POSTGRES_HOST=localhost POSTGRES_PORT=5001 POSTGRES_DB=myapp POSTGRES_USER=appuser POSTGRES_PASSWORD=dbuser123
   - pip install -r requirements.txt
   - python manage.py migrate
   - python manage.py createsuperuser  # create test user
   - python manage.py runserver 0.0.0.0:3001
3) Start Frontend (port 3000)
   - cd personal-expense-tracker-181971-181982/expense_tracker_frontend
   - cp .env.example .env  # provides REACT_APP_API_BASE=http://localhost:3001/api
   - npm install
   - npm start
   - Access via http://localhost:3000 (preview URLs on port 3000 are also allowed in CORS)

Steps
A. Create a user (if not already)
   - Done via createsuperuser above or Django admin at /admin.

B. Obtain JWT
   - In frontend: go to http://localhost:3000, login with the user.
   - Or via curl:
     curl -X POST http://localhost:3001/api/auth/token/ -H "Content-Type: application/json" -d '{"username":"<u>","password":"<p>"}'

C. CRUD operations
   - Categories: create a "Groceries" category, edit it, list it, delete it (optional).
   - Expenses: add a few expenses (some with category, some uncategorized), edit one, delete one.
   - Budgets: create a monthly budget for "Groceries" and one for "All Categories".

D. Reports
   - Summary: view Reports page; verify totals and per-category breakdown.
   - Budget status: verify spent vs budget remaining.

E. Health check
   - http://localhost:3001/api/health/ should return {"message":"Server is up!"}

Expected
- No CORS or CSRF errors in browser console.
- Frontend at port 3000 can authenticate and call backend /api endpoints at port 3001.
