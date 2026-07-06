# How to Write Modular Code

For FastAPI backend and Vue 3 frontend. Small files, single responsibility, clear layers.

---

## The Rule

**300 lines max per file. No exceptions.**

Why 300 lines?
- Fits in AI context windows without chunking
- Forces single responsibility — can't do too much in 300 lines
- Reduces merge conflicts
- Makes code review tractable

**Count:** Actual code lines. **Don't count:** Blank lines, comments, imports.

---

## Project Structure

```
backend/
├── main.py              # App setup, auth, core endpoints (split if >300)
├── database.py          # SQLAlchemy engine and session
├── database_models.py   # ORM models
├── models/
│   └── api_schemas.py   # Pydantic schemas (split by domain if grows)
├── routers/
│   └── email.py         # Email endpoints
├── services/
│   └── email_service.py # Email business logic
├── utils/
│   └── email_tracking.py# Helper functions
└── tests/

frontend/src/
├── main.js              # App entry
├── App.vue              # Root component
├── router/
│   └── index.js         # Routes and guards
├── api/
│   └── axios.js         # API client
├── components/          # One component per file
│   ├── Login.vue
│   ├── Applications.vue
│   └── ...
├── config/
│   └── api.js
└── utils/
    └── filterLabels.js
```

---

## When to Split

| Smell | Action |
|-------|--------|
| File > 300 lines | Split now |
| Method/function > 30 lines | Extract to named function |
| "And" in description | Two separate things |
| Multiple unrelated imports | Code is in wrong file |
| Scrolling to understand | Too big |

## When NOT to Split

Don't over-engineer small files:
- File under 100 lines doing one thing? Leave it alone
- 3 similar lines? Don't abstract prematurely
- Single-use helper? Keep it inline

---

## Backend Splitting Strategies

### 1. Extract Routers

When `main.py` grows, extract endpoint groups:

```python
# BEFORE: Everything in main.py

# AFTER: routers/applications.py
from fastapi import APIRouter, Depends
router = APIRouter()

@router.get("/applications/")
async def get_applications(db: Session = Depends(get_db)):
    ...

# main.py
app.include_router(applications_router, prefix="/api")
```

### 2. Extract Services

Move business logic out of endpoints:

```python
# BEFORE: Logic in endpoint
@router.post("/email/send")
async def send_email(request: EmailRequest):
    # 50 lines of SMTP logic...

# AFTER: services/email_service.py
class EmailService:
    async def send_bulk_emails(self, recipients, subject, body):
        # Business logic here

# routers/email.py - thin wrapper
@router.post("/email/send")
async def send_email(
    request: EmailRequest,
    email_service: EmailService = Depends(get_email_service)
):
    return await email_service.send_bulk_emails(...)
```

### 3. Extract Pydantic Schemas

Group by domain when `api_schemas.py` grows:

```
models/
├── user_schemas.py       # UserCreate, UserBase, User
├── application_schemas.py# ApplicationBase, Application
└── email_schemas.py      # EmailRequest, EmailResponse
```

### 4. Extract Utils

Pure functions that don't need request context:

```python
# utils/email_tracking.py
def create_email_record(apartment_id: int, date: datetime = None) -> str:
    ...

def append_email_record(existing: str, new_record: str) -> str:
    ...
```

---

## Frontend Splitting Strategies

### 1. Extract Composables

Reusable logic from components:

```javascript
// composables/useAuth.js
import { ref } from 'vue'
import axios from '../api/axios'

export function useAuth() {
  const token = ref(localStorage.getItem('token'))

  async function login(email, password) { ... }
  function logout() { ... }

  return { token, login, logout }
}

// components/Login.vue - uses composable
import { useAuth } from '../composables/useAuth'
const { login } = useAuth()
```

### 2. Extract Child Components

When a `.vue` file grows:

```vue
<!-- BEFORE: Applications.vue with 800 lines -->

<!-- AFTER: Split into -->
<!-- components/ApplicationList.vue - the table -->
<!-- components/ApplicationFilters.vue - filter UI -->
<!-- components/ApplicationActions.vue - action buttons -->

<!-- Applications.vue - thin coordinator -->
<template>
  <ApplicationFilters @filter="handleFilter" />
  <ApplicationList :applications="filtered" />
  <ApplicationActions :selected="selected" />
</template>
```

### 3. Extract API Functions

When axios calls repeat:

```javascript
// api/applications.js
import axios from './axios'

export async function getApplications(params) {
  return axios.get('/api/applications/', { params })
}

export async function deleteApplication(id) {
  return axios.delete(`/api/applications/${id}`)
}
```

### 4. Extract Utils

Pure formatting/transformation functions:

```javascript
// utils/filterLabels.js
export const areaLabels = {
  area_farjestad: 'Färjestad',
  area_bellevue: 'Bellevue',
  ...
}

export function formatDate(date) { ... }
```

---

## Layer Rules

### Backend
- `routers/` — HTTP layer, thin, delegates to services
- `services/` — Business logic, no HTTP concerns
- `models/` — Pydantic schemas (API) and SQLAlchemy models (DB)
- `utils/` — Pure functions, no dependencies on request context

### Frontend
- `components/` — Vue components, UI only
- `composables/` — Reusable reactive logic
- `api/` — HTTP client, API functions
- `utils/` — Pure functions, no Vue dependencies

**Never import up the stack.** Utils don't import services. Services don't import routers.

---

## Pre-Commit Checklist

```bash
# Backend
find backend -name "*.py" -not -path "*/venv/*" | xargs wc -l | sort -n | tail -10

# Frontend
find frontend/src -name "*.vue" -o -name "*.js" | xargs wc -l | sort -n | tail -10
```

Before committing:
- [ ] No file exceeds 300 lines
- [ ] Each file has ONE clear purpose
- [ ] Endpoints delegate to services (< 20 lines each)
- [ ] Components delegate to composables for complex logic
