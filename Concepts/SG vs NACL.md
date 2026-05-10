# NACL vs Security Group — Quick Deep Dive Notes

# 1. What is Security Group?

Security Group acts like:

```text id="g8m2vw"
Instance-level firewall
```

It controls traffic for:

* EC2
* ALB
* RDS

Security Group works at:

```text id="z4x7pt"
Resource level
```

---

# Example From Our Project

## ALB Security Group

| Port | Source    |
| ---- | --------- |
| 443  | 0.0.0.0/0 |

Allows internet users to access ALB.

---

## EC2 Security Group

| Port | Source |
| ---- | ------ |
| 8000 | ALB SG |

Only ALB can access application server.

---

# Important Characteristics of Security Group

| Feature     | Behavior          |
| ----------- | ----------------- |
| Stateful    | Yes               |
| Allow Rules | Yes               |
| Deny Rules  | No                |
| Applied To  | Instance/Resource |
| Evaluates   | Only allow rules  |

---

# What Does Stateful Mean?

If inbound traffic allowed:

```text id="s9v5yc"
Response traffic automatically allowed back
```

No need separate outbound rule.

---

# Example

If:

```text id="n4x2pw"
HTTPS inbound allowed
```

then return traffic automatically works.

---

# 2. What is NACL?

NACL = Network Access Control List

Acts like:

```text id="t3m8za"
Subnet-level firewall
```

Controls traffic for:

* entire subnet

NACL works at:

```text id="r5y1kf"
Subnet boundary
```

---

# Important Characteristics of NACL

| Feature     | Behavior   |
| ----------- | ---------- |
| Stateful    | No         |
| Allow Rules | Yes        |
| Deny Rules  | Yes        |
| Applied To  | Subnet     |
| Evaluates   | Rule order |

---

# What Does Stateless Mean?

If inbound traffic allowed:

```text id="m7q4lx"
Outbound response must also be explicitly allowed
```

Otherwise traffic fails.

---

# Example

Need BOTH:

| Direction | Rule                  |
| --------- | --------------------- |
| Inbound   | Allow 443             |
| Outbound  | Allow ephemeral ports |

---

# 3. Security Group vs NACL

| Feature          | Security Group      | NACL              |
| ---------------- | ------------------- | ----------------- |
| Works At         | Instance level      | Subnet level      |
| Stateful         | Yes                 | No                |
| Supports Deny    | No                  | Yes               |
| Rule Processing  | All rules evaluated | Rule number order |
| Default Behavior | Deny inbound        | Allow all         |
| Best For         | Resource protection | Subnet protection |

---

# 4. Real Traffic Flow Understanding

Suppose request comes:

```text id="n2p7tw"
Internet
 ↓
NACL
 ↓
Security Group
 ↓
EC2
```

Both must allow traffic.

If either blocks:

* traffic fails

---

# 5. Why Security Groups Used More Often?

Because Security Groups are:

* simpler
* stateful
* easier to manage

Most AWS projects primarily rely on:

* Security Groups

NACLs used for:

* extra subnet protection
* compliance
* enterprise restrictions

---

# 6. Real Example From Our Project

---

# ALB Security Group

Allowed:

| Port | Source    |
| ---- | --------- |
| 443  | 0.0.0.0/0 |

Internet can access ALB.

---

# EC2 Security Group

Allowed:

| Port | Source |
| ---- | ------ |
| 8000 | ALB SG |

Only ALB can access app.

---

# RDS Security Group

Allowed:

| Port | Source |
| ---- | ------ |
| 5432 | EC2 SG |

Only app servers can access DB.

---

# Why This Is Secure?

Because users CANNOT directly access:

* EC2
* RDS

Only ALB is public.

---

# 7. Real Use Cases of NACL

NACLs commonly used for:

* blocking suspicious IP ranges
* subnet-level restrictions
* compliance rules
* extra defense layer

---

# Example

Block one IP:

| Rule          | Action |
| ------------- | ------ |
| Deny 45.x.x.x | DENY   |

Security Groups cannot do this.

---

# 8. Rule Number Importance in NACL

NACL rules processed in order:

```text id="k5m8pv"
100 → 200 → 300
```

First matching rule wins.

---

# Example

| Rule          | Action |
| ------------- | ------ |
| 100 Allow 443 | Allow  |
| 110 Deny IP   | Deny   |

Order matters.

---

# 9. Default NACL vs Custom NACL

---

# Default NACL

Allows:

* all inbound
* all outbound

---

# Custom NACL

You manually define:

* allow rules
* deny rules

More secure.

---

# 10. Important Interview Questions

---

# Q) Difference Between Security Group and NACL?

### Answer

```text id="x1w6pt"
Security Group works at instance level and is stateful.
NACL works at subnet level and is stateless.

Security Groups support only allow rules,
while NACL supports both allow and deny rules.
```

---

# Q) What Does Stateful Mean?

### Answer

```text id="h4r9zy"
In stateful firewalls, return traffic is automatically allowed.
Security Groups are stateful.
```

---

# Q) Why Are NACLs Stateless?

### Answer

```text id="b7p2mq"
NACL requires explicit inbound and outbound rules separately
because it does not automatically track connection state.
```

---

# Q) Which Is Evaluated First — NACL or Security Group?

### Answer

```text id="q9x5vk"
NACL is evaluated first at subnet level,
then Security Group is evaluated at instance level.
```

---

# Q) Why Use NACL If Security Groups Already Exist?

### Answer

```text id="n8c4tw"
NACL provides subnet-level protection and supports deny rules,
making it useful for additional security layers and compliance requirements.
```

---

# 11. Final Simple Understanding

```text id="v6z1ry"
Security Group = Instance Firewall

NACL = Subnet Firewall
```

---

# 12. Easy Memory Trick

```text id="y5m7qa"
Security Group protects SERVER

NACL protects SUBNET
```
