# How to TDD – pytest (Backend) & Vitest (Frontend)

Goal: small, fast, trustworthy tests that let you change code without fear.

---

## Agent Loop: How to Work Test-First

For each change or bugfix:

1. **Clarify behavior**
   - Rephrase the requirement as one or more user-observable outcomes
   - Identify inputs, outputs, and side-effects

2. **Choose the test level**
   - Unit if a single function/module behavior
   - Integration if endpoint + database behavior
   - Component if Vue component behavior

3. **Write the test first**
   - Name describes behavior, not implementation
   - Use AAA (Arrange–Act–Assert)
   - Make sure it fails for the right reason

4. **Implement the minimal code**
   - Only write enough code to make the new test pass
   - Do not "future-proof" or add behavior without tests

5. **Refactor**
   - Clean the code and tests while all tests are green
   - Remove duplication, tighten naming, simplify mocks

Repeat for each behavior.

---

## Core Pattern: Arrange–Act–Assert (AAA)

Each test should read like a story:

- **Arrange:** Set up inputs, mocks, and state (fixtures, factories, stubs)
- **Act:** Execute one action (call function, fire event, submit form)
- **Assert:** Verify the observable outcome (return value, response, DOM change)

Prefer one primary assertion per behavior. Extra assertions are okay if they are part of the same behavior.

---

## Backend Testing (pytest)

### Project Setup

Tests live in `backend/tests/`. Key files:
- `conftest.py` — shared fixtures (test DB, test client)
- `test_*.py` — test modules

### Running Tests

```bash
cd backend && source venv/bin/activate && python -m pytest
```

### Key Fixtures (from conftest.py)

```python
@pytest.fixture
def test_db():
    """In-memory SQLite database for isolation"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def client(test_db):
    """FastAPI TestClient with overridden DB dependency"""
    app.dependency_overrides[get_db] = lambda: test_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
```

### Testing Patterns

**Endpoint test:**
```python
def test_create_application_returns_201(client):
    response = client.post("/api/applications/random/")
    assert response.status_code == 200
    assert "name" in response.json()
```

**Mocking external services:**
```python
@pytest.fixture
def mock_smtp():
    with patch('smtplib.SMTP') as mock:
        mock_server = MagicMock()
        mock.return_value.__enter__.return_value = mock_server
        yield mock_server

def test_email_sends_successfully(client, mock_smtp):
    mock_smtp.send_message.return_value = {}
    response = client.post("/email/send", json={...})
    assert response.json()["status"] == "success"
```

**Mocking environment variables:**
```python
@pytest.fixture(autouse=True)
def mock_env_vars():
    with patch.dict('os.environ', {'SMTP_SERVER': 'test.com'}):
        yield
```

### What to Test

| Layer | Test |
|-------|------|
| Endpoints | Request/response, status codes, validation errors |
| Database | CRUD operations with test_db fixture |
| Services | Business logic with mocked dependencies |
| Auth | Token generation, protected routes |

---

## Frontend Testing (Vitest)

### Project Setup

Tests live in `frontend/tests/`. Use `*.test.js` naming.

### Running Tests

```bash
cd frontend && npx vitest run
```

### Key Patterns

**Component mounting:**
```javascript
import { mount } from '@vue/test-utils'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import Login from '../src/components/Login.vue'

describe('Login.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders login form', () => {
    const wrapper = mount(Login, {
      global: { plugins: [router] }
    })
    expect(wrapper.find('h2').text()).toBe('Login')
  })
})
```

**Mocking axios:**
```javascript
import axios from 'axios'
vi.mock('axios')

it('calls API on submit', async () => {
  axios.post.mockResolvedValueOnce({ data: { access_token: 'token' } })

  const wrapper = mount(Login, { global: { plugins: [router] } })
  await wrapper.find('input[type="email"]').setValue('test@example.com')
  await wrapper.find('form').trigger('submit.prevent')

  expect(axios.post).toHaveBeenCalledWith(
    'http://localhost:8000/api/token',
    expect.any(FormData),
    expect.any(Object)
  )
})
```

**Mocking localStorage:**
```javascript
const localStorageMock = {
  getItem: vi.fn(),
  setItem: vi.fn(),
  clear: vi.fn()
}
global.localStorage = localStorageMock
```

**Mocking router:**
```javascript
import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: Login },
    { path: '/applications', component: { template: '<div>Apps</div>' } }
  ]
})
router.push = vi.fn()
```

### What to Test

| Layer | Test |
|-------|------|
| Components | Renders correctly, user interactions, form submissions |
| API calls | Correct endpoints, request data, response handling |
| Router | Navigation on success/failure, auth guards |
| State | localStorage reads/writes, reactive updates |

---

## Test Writing Principles

- **One behavior per test** — titles describe what the user sees or system does
- **Deterministic** — no uncontrolled randomness or real network calls
- **Mock at boundaries** — mock SMTP, axios, localStorage, not internal functions
- **Explicit assertions** — avoid snapshots for dynamic content
- **Realistic data shapes** — minimal but valid fixtures
- **Clear naming** — `it("shows error when login fails")` not `it("handles error")`

---

## PR-Ready Checklist

Before considering work "done":

- [ ] Tests are deterministic and fast
- [ ] No real network, SMTP, or external API calls
- [ ] Mocks are minimal and reset between tests
- [ ] Each requirement has at least one test
- [ ] Happy path and critical error paths covered
- [ ] All tests pass: `pytest` and `npx vitest run`
