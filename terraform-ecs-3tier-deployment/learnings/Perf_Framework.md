# Performance Testing Learning Notes (k6)

## Purpose

These notes capture my understanding of the performance testing framework used in this project. The goal is to understand not only how to execute the scripts but also how they are implemented.

---

# Performance Testing Flow

```
Smoke Test
    │
    ▼
Load Test
    │
    ▼
Stress Test
    │
    ▼
Cloud Load Testing
```

---

# Smoke Test

Purpose:

- Verify application is healthy.
- Verify important APIs are working.
- Verify complete user journey works.
- Only 1 Virtual User.
- Only 1 Iteration.

Smoke Test answers:

> "Is the application working correctly?"

---

# Load Test

Purpose:

Simulate multiple concurrent users using the application.

Checks:

- Response time
- Error rate
- Throughput
- API correctness
- Business correctness

Load Test answers:

> "Can the application handle expected production traffic?"

---

# Virtual User (VU)

A Virtual User is a simulated user created by k6.

Example:

```
vus: 50
```

means

```
50 users
```

are executing the script simultaneously.

---

# Iteration

One complete execution of the default() function.

Example

```
1 Virtual User

↓

Run Quiz

↓

Submit Quiz

↓

Leaderboard

↓

Completed

=

1 Iteration
```

---

# runQuizJourney()

This function simulates one complete user journey.

Flow

```
Generate Player Name
        │
        ▼
POST /start
        │
        ▼
Receive Session ID
        │
        ▼
Receive Questions
        │
        ▼
Sleep 0.5 sec
        │
        ▼
Generate Answers
        │
        ▼
POST /submit
        │
        ▼
Validate Score
        │
        ▼
GET Leaderboard
        │
        ▼
GET Statistics
```

This is called a **stateful user journey**, because every API depends on data returned from the previous API.

---

# Helper Functions

## baseUrl()

Returns

```
BASE_URL
```

from environment variables.

If not available,

returns

```
http://localhost:8000
```

---

## topicSlug()

Returns topic from

```
TOPIC
```

environment variable.

If not present,

returns default topic.

---

## jsonHeaders()

Returns

```json
{
  "Content-Type": "application/json",
  "Accept": "application/json"
}
```

Used by every POST request.

---

## playerName()

Creates a unique player.

Example

```
VU = 12
Iteration = 7
```

returns

```
loadtest-vu12-iter7
```

This avoids duplicate player names.

---

# check()

check() validates API responses.

Example

```javascript
check(response,{
    "Status 200": (r)=>r.status==200,
    "Has Session": (r)=>!!r.json("session_id")
})
```

check() receives

- HTTP Response
- Collection of Validation Rules

Internally it executes every validation.

```
Validation 1

↓

PASS

↓

Validation 2

↓

PASS

↓

Validation 3

↓

FAIL
```

The validation names appear in the k6 report.

Example

```
✓ Status 200

✓ Has Session

✗ Has Questions
```

---

# Why check() is useful

HTTP Status 200 does not always mean the application is correct.

Example

```
HTTP 200

Questions = []
```

Status is OK,

but business logic failed.

Therefore performance tests should validate:

- Status Code
- JSON Structure
- Required Fields
- Business Logic

---

# JavaScript Concepts Learned

## Function

```
function add(a,b)
```

Equivalent to Java method.

---

## Parameters

```
add(10,20)
```

10 and 20 are parameters passed to the function.

---

## Return

```
return value;
```

Returns result back to the caller.

---

## Function Reference

```
const a = square;
```

Stores the function itself.

Function is NOT executed.

---

## Function Call

```
square(5)
```

Executes the function.

---

## Arrow Function

```
(r)=>r.status==200
```

Equivalent to Java Lambda

```
r -> r.getStatus()==200
```

---

## Callback Function

A callback is a function passed to another function so it can execute it later.

Example

```
check(response,{
    "Status": (r)=>r.status==200
})
```

The callback is executed by check().

---

## Objects

JavaScript

```javascript
{
    headers: ...,
    tags:{
        name:"quiz_start"
    }
}
```

Equivalent to Java

```
Map<String,Object>
```

Objects store key-value pairs.

---

## Template Literals

```
`loadtest-vu${vu}-iter${iter}`
```

Equivalent to Java

```
"loadtest-vu"+vu+"-iter"+iter
```

---

## Environment Variables

```
__ENV.BASE_URL
```

Reads

```
BASE_URL
```

provided while executing k6.

---

# Performance Testing Best Practices

Always validate:

- HTTP Status
- JSON Body
- Required Fields
- Business Logic

Do not rely only on HTTP 200.

---

# Key Learnings

- Smoke Test verifies functionality.
- Load Test verifies performance under expected traffic.
- Helper functions avoid duplicate code.
- check() validates business correctness.
- Virtual Users simulate real users.
- Every iteration executes one complete user journey.
- Functions can be passed as parameters (callbacks).
- k6 uses callbacks extensively.
- Every API call can have independent validations.
- Professional performance tests validate both API success and business correctness.