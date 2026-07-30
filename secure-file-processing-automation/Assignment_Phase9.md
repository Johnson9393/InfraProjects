# Assignment - Phase 9
# Implement ECS Service Auto Scaling using Amazon SQS and CloudWatch

## Objective

In this phase, we implemented **automatic scaling** for the File Scanner application running on Amazon ECS (Fargate).

Previously, one ECS task was always running even when there were no files to process. This resulted in unnecessary compute cost.

Using **Amazon CloudWatch**, **Amazon SQS**, and **Application Auto Scaling**, the ECS service now automatically:

- Starts a task when a new message arrives in SQS.
- Stops the task after all messages are processed.

This implementation is commonly known as **Scale to Zero**.

---

# Architecture

```text
                    +----------------------+
                    |   Amazon S3          |
                    | Landing Bucket       |
                    +----------+-----------+
                               |
                               | S3 Event Notification
                               |
                               ▼
                    +----------------------+
                    |      Amazon SQS      |
                    +----------+-----------+
                               |
             Queue > 0         |          Queue = 0
          CloudWatch Alarm     |      CloudWatch Alarm
          (Scale Out)          |      (Scale In)
                │              |             │
                ▼              |             ▼
      Application Auto Scaling |  Application Auto Scaling
                │              |             │
                └──────┬───────┘
                       ▼
             Amazon ECS Service
             Desired Count (0 ⇄ 1)
                       │
                       ▼
              ECS Fargate Task
                       │
        ┌──────────────┼──────────────┐
        │ Download File               │
        │ ClamAV Scan                 │
        │ Tag Object                  │
        │ Move File                   │
        │ Publish SNS Notification    │
        │ Delete SQS Message          │
        └─────────────────────────────┘
```

---

# Why Auto Scaling?

Before this phase

```text
Desired Tasks = 1

↓

One ECS task was always running.

↓

Compute charges were incurred even when
there were no files to process.
```

After this phase

```text
No Queue Messages

↓

Desired Tasks = 0

↓

No ECS Task Running

↓

No unnecessary compute cost
```

Whenever a file arrives

```text
S3 Upload

↓

SQS Message

↓

CloudWatch Alarm

↓

Desired Tasks = 1

↓

Worker Starts Automatically
```

---

# Step 1 - Enable Service Auto Scaling

Navigation

```
Amazon ECS

↓

Clusters

↓

file-scanner-cluster

↓

Services

↓

file-scanner-service

↓

Update Service
```

---

# Configure Service Auto Scaling

Minimum Tasks

```
0
```

Maximum Tasks

```
1
```

## Explanation

Minimum Tasks

```
0
```

Means

When there are no messages in Amazon SQS, ECS can completely stop all running tasks.

Maximum Tasks

```
1
```

Means

Only one File Scanner worker can run at a time.

This is sufficient because our worker processes one file at a time.

In future this value can easily be increased to

```
2

5

10
```

without changing application code.

---

# Step 2 - Create Scale Out Policy

Policy Type

```
Step Scaling
```

Policy Name

```
file-scanner-scale-out
```

---

# Configure CloudWatch Alarm

Navigation

```
CloudWatch

↓

Alarms

↓

Create Alarm
```

Select Metric

```
Amazon SQS

↓

Per Queue Metrics

↓

ApproximateNumberOfMessagesVisible
```

Configuration

```
Statistic

Average
```

```
Period

1 Minute
```

Condition

```
Greater Than
```

Threshold

```
0
```

Alarm Name

```
file-scanner-scale-out-alarm
```

---

# Why Greater Than 0?

When

```
ApproximateNumberOfMessagesVisible > 0
```

it means

At least one message is waiting in Amazon SQS.

Example

```
Queue

1 Message
```

or

```
Queue

10 Messages
```

or

```
Queue

500 Messages
```

In all these cases

```
Queue > 0
```

Therefore

CloudWatch changes the alarm state to

```
ALARM
```

which triggers the Scale Out policy.

---

# Configure Step Scaling Action

Action

```
Add
```

Value

```
1
```

Type

```
Tasks
```

Lower Bound

```
0
```

Upper Bound

```
+Infinity
```

Cooldown

```
60 Seconds
```

---

# Explanation

Action

```
Add
```

Means

Increase the ECS Desired Task Count.

Value

```
1
```

Means

Start exactly one additional ECS Task.

Type

```
Tasks
```

Means

Scale by the number of ECS Tasks.

Lower Bound

```
0
```

Means

Whenever the CloudWatch metric breach starts from zero or above, this scaling action becomes applicable.

Upper Bound

```
Infinity
```

Means

No upper limit for this metric range.

Cooldown

```
60 Seconds
```

Means

Wait for one minute before executing another Scale Out action.

This prevents continuous scaling due to temporary metric spikes.

---

# Step 3 - Create Scale In Policy

Policy Type

```
Step Scaling
```

Policy Name

```
file-scanner-scale-in
```

---

# Create Scale In Alarm

Navigation

```
CloudWatch

↓

Alarms

↓

Create Alarm
```

Select Metric

```
Amazon SQS

↓

Per Queue Metrics

↓

ApproximateNumberOfMessagesVisible
```

Configuration

```
Statistic

Average
```

```
Period

1 Minute
```

Condition

```
Less Than Or Equal To
```

Threshold

```
0
```

Alarm Name

```
file-scanner-scale-in-alarm
```

---

# Why Less Than Or Equal To 0?

When

```
ApproximateNumberOfMessagesVisible <= 0
```

it means

No messages are waiting in Amazon SQS.

Example

```
Queue

0 Messages
```

Since there is nothing left to process,

CloudWatch changes the alarm state to

```
ALARM
```

which triggers the Scale In policy.

---

# Configure Scale In Action

Action

```
Remove
```

Value

```
1
```

Type

```
Tasks
```

Lower Bound

```
-Infinity
```

Upper Bound

```
0
```

Cooldown

```
60 Seconds
```

---

# Explanation

Action

```
Remove
```

Means

Reduce the ECS Desired Task Count.

Value

```
1
```

Means

Stop one ECS Task.

Upper Bound

```
0
```

Means

Whenever the metric reaches zero or below, execute this Scale In action.

Cooldown

```
60 Seconds
```

Allows the worker enough time to finish processing before another scaling activity occurs.

---

# CloudWatch Alarms Created

Scale Out

```
file-scanner-scale-out-alarm
```

Condition

```
ApproximateNumberOfMessagesVisible > 0
```

Purpose

```
Start ECS Task
```

---

Scale In

```
file-scanner-scale-in-alarm
```

Condition

```
ApproximateNumberOfMessagesVisible <= 0
```

Purpose

```
Stop ECS Task
```

---

# Scaling Policies Created

```
file-scanner-scale-out
```

Purpose

```
Increase Desired Count
```

---

```
file-scanner-scale-in
```

Purpose

```
Decrease Desired Count
```

---

# End-to-End Verification

Verified Successfully

✅ Desired Tasks initially remained

```
0
```

---

Uploaded a file into

```
Landing Bucket
```

---

Verified

```
Amazon SQS

↓

Message Created
```

---

Verified

```
CloudWatch Scale Out Alarm

↓

ALARM
```

---

Verified

```
Desired Count

0

↓

1
```

---

Verified

```
ECS Task Started
```

---

Verified

```
Worker Processed File
```

---

Verified

```
Landing Bucket

↓

Clean Bucket
```

---

Verified

```
SQS Message Deleted
```

---

Verified

```
CloudWatch Scale In Alarm

↓

ALARM
```

---

Verified

```
Desired Count

1

↓

0
```

---

Verified

```
Running Tasks

0
```

---

# Phase 9 Outcome

Successfully implemented **event-driven auto scaling** for the File Scanner application using:

- Amazon ECS (Fargate)
- Amazon SQS
- Amazon CloudWatch Alarms
- Application Auto Scaling
- Step Scaling Policies

The application now starts automatically when work is available and scales back to zero when the queue becomes empty, reducing unnecessary compute costs while maintaining full functionality.

---
