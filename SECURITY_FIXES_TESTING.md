# Security Fixes - Testing Guide

## Overview
This document describes how to test the critical security fixes implemented in Phase 1.

## Changes Made (Phase 1)

### 1. SQL Injection Fixes (12 instances)
**Files Modified:**
- `server/log.go` - Query parameterization for log search
- `server/call.go` - Query parameterization for duplicate check and call retrieval
- `server/database.go` - Query parameterization for migration checks
- `server/access.go` - Parameterized IN clause for delete operations
- `server/apikey.go` - Parameterized IN clause for delete operations
- `server/downstream.go` - Parameterized IN clause for delete operations
- `server/group.go` - Parameterized IN clause for delete operations
- `server/tag.go` - Parameterized IN clause for delete operations
- `server/dirwatch.go` - Parameterized IN clause for delete operations
- `server/system.go` - Parameterized IN clause for delete operations (3 queries)
- `server/talkgroup.go` - Parameterized IN clause for delete operations
- `server/unit.go` - Parameterized IN clause for delete operations

**What was fixed:** Replaced string interpolation with parameterized queries using `?` placeholders and `args...` parameter passing.

**Example of fix:**
```go
// BEFORE (vulnerable to SQL injection)
query := fmt.Sprintf("delete from `table` where `id` in %v", userInput)

// AFTER (secure with parameterized query)
placeholders := make([]string, len(ids))
args := make([]any, len(ids))
for i, id := range ids {
    placeholders[i] = "?"
    args[i] = id
}
query := fmt.Sprintf("delete from `table` where `id` in (%s)", strings.Join(placeholders, ","))
db.Exec(query, args...)
```

### 2. CORS Vulnerability Fix
**File Modified:** `server/main.go`

**What was fixed:**
- Changed WebSocket `CheckOrigin` from always returning `true` (accepts all origins)
- Now validates origins to prevent CSRF attacks
- Allows same-origin requests
- Allows localhost for development
- Rejects all other origins

**Before:**
```go
CheckOrigin: func(r *http.Request) bool {
    return true  // DANGEROUS!
}
```

**After:**
```go
CheckOrigin: func(r *http.Request) bool {
    origin := r.Header.Get("Origin")
    if origin == "" {
        return true // Non-browser clients
    }
    originURL, err := url.Parse(origin)
    if err != nil {
        return false
    }
    // Validate same-origin or localhost
    if originURL.Host == r.Host {
        return true
    }
    if strings.HasPrefix(originURL.Host, "localhost:") ||
       strings.HasPrefix(originURL.Host, "127.0.0.1:") ||
       strings.HasPrefix(originURL.Host, "[::1]:") {
        return true
    }
    return false
}
```

### 3. Hardcoded Default Password Removal
**Files Modified:**
- `server/defaults.go` - Password generation
- `server/options.go` - First-time setup logging

**What was fixed:**
- Removed hardcoded `"rdio-scanner"` password
- Generates cryptographically secure random 22-character password on startup
- Uses `crypto/rand` for 128-bit entropy
- Logs password prominently on first-time setup
- Still forces password change on first login

**Changes:**
```go
// BEFORE
adminPassword: "rdio-scanner",  // HARDCODED!

// AFTER
adminPassword: generateSecurePassword(),  // Crypto-random

func generateSecurePassword() string {
    bytes := make([]byte, 16)
    rand.Read(bytes)
    return base64.URLEncoding.EncodeToString(bytes)[:22]
}
```

---

## How to Build and Test

### Prerequisites
1. Go 1.18 or later installed
2. Node.js 16+ for Angular frontend
3. Database (SQLite, MySQL, or MariaDB)

### Step 1: Build the Server

```bash
cd /home/jtetterton/claude_projects/my-rdio-scanner/server

# Install dependencies
go mod download

# Build the server
go build -o rdio-scanner

# Or build for specific platform
make linux-amd64
```

### Step 2: Run the Server

```bash
# Run with default settings
./rdio-scanner

# You should see a message like:
# ═══════════════════════════════════════════════════════════
#   FIRST-TIME SETUP DETECTED
#   Initial admin password: Xk9mP2nQ7vR8sT1uW3yZ
#   WARNING: You MUST change this password on first login!
# ═══════════════════════════════════════════════════════════

# IMPORTANT: Save this password! You'll need it to log in.
```

### Step 3: Test SQL Injection Protection

#### Test 1: Admin Log Search
1. Log in to admin panel at `http://localhost:3000/admin`
2. Navigate to System Logs
3. Try entering SQL injection attempts in the search:
   - Level filter: `info' OR '1'='1`
   - Date filter: malicious SQL
4. **Expected Result:** No SQL errors, searches should work normally or return no results

#### Test 2: Call Search
1. Use the call search API endpoint
2. Send POST to `/api/admin/call-search` with malicious input
3. **Expected Result:** No SQL injection, parameters are safely escaped

#### Test 3: Delete Operations
1. Try deleting access codes, API keys, groups, tags, systems
2. Monitor server logs for SQL queries
3. **Expected Result:** All DELETE queries use parameterized IN clauses

### Step 4: Test CORS Protection

#### Test 1: Valid Same-Origin Request
```bash
# Should succeed - same origin
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Host: localhost:3000" \
  -H "Origin: http://localhost:3000" \
  http://localhost:3000/
```
**Expected:** HTTP 101 Switching Protocols (WebSocket upgrade succeeds)

#### Test 2: Invalid Cross-Origin Request
```bash
# Should fail - different origin
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Host: localhost:3000" \
  -H "Origin: http://evil.com" \
  http://localhost:3000/
```
**Expected:** HTTP 403 Forbidden or connection rejected

#### Test 3: Localhost Requests
```bash
# Should succeed - localhost
curl -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Host: localhost:3000" \
  -H "Origin: http://127.0.0.1:3000" \
  http://localhost:3000/
```
**Expected:** HTTP 101 Switching Protocols (allowed for development)

### Step 5: Test Secure Password Generation

#### Test 1: First-Time Setup
1. Delete your database file (backup first!)
2. Start the server
3. **Expected Output:**
   ```
   ═══════════════════════════════════════════════════════════
     FIRST-TIME SETUP DETECTED
     Initial admin password: [22-character random string]
     WARNING: You MUST change this password on first login!
   ═══════════════════════════════════════════════════════════
   ```
4. Password should be different each time you do fresh setup

#### Test 2: Password Strength
1. Check that generated password is:
   - 22 characters long
   - Contains mix of letters, numbers, and symbols
   - Different on each fresh install
2. Try logging in with the displayed password
3. **Expected:** Login succeeds, prompted to change password

#### Test 3: Command-Line Password Change
```bash
./rdio-scanner -admin-password "MyNewSecurePassword123!"
```
**Expected:** Password successfully changed, server exits

---

## Verification Checklist

### SQL Injection Protection ✓
- [ ] Log search doesn't allow SQL injection
- [ ] Call search safely handles malicious input
- [ ] Delete operations use parameterized queries
- [ ] No SQL errors in logs when testing malicious input

### CORS Protection ✓
- [ ] Same-origin WebSocket connections succeed
- [ ] Cross-origin WebSocket connections are rejected
- [ ] Localhost connections work for development
- [ ] No WebSocket upgrade from untrusted origins

### Secure Password ✓
- [ ] No hardcoded password in source code
- [ ] Random password generated on fresh install
- [ ] Password displayed prominently on first run
- [ ] Password different on each fresh setup
- [ ] Password change still works via CLI flag

---

## Security Testing Tools

### 1. SQL Injection Testing with sqlmap
```bash
# Test log search endpoint
sqlmap -u "http://localhost:3000/api/admin/logs" \
  --cookie="rdio-scanner-admin-token=YOUR_TOKEN" \
  --data='{"level":"info"}' \
  --batch

# Expected: Should find NO SQL injection vulnerabilities
```

### 2. WebSocket CORS Testing with wscat
```bash
npm install -g wscat

# Test invalid origin
wscat -c ws://localhost:3000 \
  -H "Origin: http://evil.com"

# Expected: Connection should be rejected
```

### 3. Password Entropy Testing
```bash
# Run fresh setup 10 times, check password uniqueness
for i in {1..10}; do
  rm rdio-scanner.db
  ./rdio-scanner 2>&1 | grep "Initial admin password"
done

# Expected: 10 different passwords
```

---

## Rollback Instructions

If you need to revert these changes:

```bash
# Check what was changed
git diff HEAD

# Restore original code
git checkout server/access.go
git checkout server/apikey.go
git checkout server/call.go
git checkout server/database.go
git checkout server/defaults.go
git checkout server/dirwatch.go
git checkout server/downstream.go
git checkout server/group.go
git checkout server/log.go
git checkout server/main.go
git checkout server/options.go
git checkout server/system.go
git checkout server/tag.go
git checkout server/talkgroup.go
git checkout server/unit.go

# Rebuild
go build
```

---

## Known Issues / Limitations

1. **CORS Trusted Origins**: Currently only same-origin and localhost are allowed. Need to add configuration option for custom trusted origins.

2. **First-Time Password Display**: Password only shown on console. In production, consider logging to file or requiring initial password via environment variable.

3. **API Key Hashing**: Not yet implemented (Phase 2). API keys are still stored in plaintext in the database.

4. **Rate Limiting**: Not yet implemented (Phase 2). Authentication endpoints can be brute-forced.

---

## Next Steps (Phase 2)

After verifying these fixes work:
1. Implement API key hashing
2. Add rate limiting to authentication endpoints
3. Fix frontend base64 password encoding
4. Add comprehensive test suite

---

## Support

If you encounter any issues:
1. Check server logs for errors
2. Verify Go version: `go version` (need 1.18+)
3. Verify database connection works
4. Check file permissions on database file
5. Review this testing guide step-by-step

---

**Generated:** 2025-10-24
**Phase:** 1 of 8 (Critical Security Fixes)
**Status:** Ready for Testing
