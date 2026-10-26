# RabbitMQ vs Kafka — ShopSphere

This note is the broker choice for ShopSphere. The running app uses **RabbitMQ**. Kafka is here so you can explain the difference in interviews and know when we would add it later.

The example throughout is **order created → confirmation email**.

---

## The problem both brokers solve

ShopSphere has two services in this path:

- **Order service** creates the order.
- **Notification service** sends the confirmation email through AWS SES.

If the order service called notification on the same HTTP request, a slow or down email path would delay or fail the order. The customer is waiting on checkout. Email is not part of “order saved.”

A **message broker** sits in the middle. The order service publishes an event and returns. Notification consumes that event when it is up and then sends the email. The two services are not tightly coupled.

```text
Customer places order
        |
Order service saves the order
        |
publishes order_created
        |
    [ broker ]
        |
Order API returns to the customer

Later:
Notification service consumes the event
        |
AWS SES sends the email
```

If notification is down, the event waits in the broker. When notification comes back, the user still gets the email. The order was already created.

---

## What is RabbitMQ?

RabbitMQ is a **message broker that uses queues**.

A service publishes a message into RabbitMQ. That message waits in a queue. A downstream service consumes it when it is up.

Interview line:

> RabbitMQ is a queuing service. Events wait in a queue. Downstream systems consume them when they are up.

The broker is the system. The **queue** is where messages wait.

ShopSphere already does this in code:

- Order service publishes to exchange `order_events` with routing key `order.created`.
- Notification service binds queue `notification_queue` to that routing key and consumes it.

---

## RabbitMQ concepts

```text
Producer  →  Exchange  →  Queue  →  Consumer
```

**Producer** — the service that sends the message. In ShopSphere this is the order service.

**Exchange** — the door into RabbitMQ. The producer does not write straight into a queue name. It publishes to an exchange. ShopSphere uses exchange `order_events` (topic exchange).

**Routing key** — the label on the message. ShopSphere uses `order.created`. The exchange uses that label to decide which queue gets the message.

**Queue** — the waiting list. ShopSphere uses `notification_queue`. The event sits here if notification is down.

**Consumer** — the service that reads from the queue and does the work. In ShopSphere this is the notification service, which then calls SES.

**Acknowledgement (ack)** — after notification successfully handles the message, it acks. RabbitMQ then removes it from that queue. If the consumer crashes before ack, RabbitMQ can give the message to a consumer again.

**Durable queue / persistent message** — the queue and message can survive a RabbitMQ restart, if we configure that. That is not the same as Kafka retention. After a successful ack, the message is gone from the queue.

**Dead-letter queue** — if a message fails too many times, it can be moved aside instead of blocking the main queue.

**Ports** (from docker-compose): `5672` is AMQP, the app protocol. `15672` is the management UI at `http://localhost:15672`.

Competing consumers on **one** queue share the work. Message A goes to consumer 1, message B to consumer 2. They do not each get a full copy of every message.

---

## How RabbitMQ solves ShopSphere’s issue

Without a broker:

```text
Order service → Notification service → SES → then respond to user
```

If notification is down, the user does not get a clean “order created,” or the order API waits and times out.

With RabbitMQ:

```text
Order service job is done after:
  1. order row is saved
  2. order_created is published to RabbitMQ

Notification job is separate:
  consume from notification_queue → send email
```

There is no runtime dependency that notification must be up at the exact second of checkout. The broker stores the event until the consumer is enabled.

Dev runs this broker as an **in-cluster RabbitMQ pod**. That is enough to learn the flow. Prod will not rely on one pod. Prod will use **Amazon MQ** (AWS-managed RabbitMQ) for high availability, the same split as Redis: in-cluster for dev, ElastiCache for prod.

---

## What is Kafka?

Kafka is a **message broker** and an **event streaming platform**.

It uses **topics**, not queues. Producers write events to a topic. **Consumers** read from that topic. People sometimes say “subscribers.” In Kafka interviews, say **topics, partitions, and consumers**.

The important extra: Kafka keeps those events in a **durable log** for a retention period. Consumers can replay. RabbitMQ’s default model is not that.

Interview line:

> Kafka is a message broker that stores events in a topic as a log. Multiple consumers can read the same events, even later, from an offset.

---

## Kafka concepts

```text
Producer  →  Topic (split into partitions)  →  Consumer groups
```

**Producer** — writes events, for example `OrderCreated`, to a topic such as `orders`.

**Topic** — the named stream. Not a queue. Many events of the same kind live here.

**Partition** — a slice of a topic. One topic can have several partitions so Kafka can spread load across brokers. Each partition is an ordered log. Order is kept **inside** a partition. Across partitions, order is not guaranteed.

That is how Kafka scales: more partitions, more consumers in a group, more parallel reads. RabbitMQ does not use partitions.

**Offset** — the consumer’s position in a partition, like a bookmark. “I have read up to message 1042.”

**Consumer group** — a team of consumers sharing work on a topic. One group: each event is processed once by that group (each partition assigned to one member). **Different groups** can each read the **same** events independently (notification, analytics, fraud).

**Retention** — Kafka keeps the log for a configured time or size, even after consumers have read it. That is how replay works.

**Replay** — a new consumer group, or a reset offset, can read yesterday’s `OrderCreated` events again. RabbitMQ does not keep a long history for that after ack.

---

## Message vs event (useful mental model)

**RabbitMQ message:** “Send this email.” The consumer’s job is to do that work. After ack, that work item is done.

**Kafka event:** “Order 123 was created.” Any system can decide what to do with that fact. Notification sends email. Analytics updates counts. Fraud scores the order. A new recommendation service can start tomorrow and still read the stream if it is within retention.

ShopSphere today only needs the work item: send the confirmation email. That is RabbitMQ.

---

## How consumers differ

**RabbitMQ — one queue, competing consumers**

```text
notification_queue
        |
   Message A, B, C
        |
   ┌────┴────┐
   ↓         ↓
Notif pod 1  Notif pod 2
```

Each message is processed by one of those pods, then removed after ack.

**Kafka — one topic, many independent groups**

```text
orders topic
        |
   OrderCreated events stay in the log
        |
   ├── Notification group   (email)
   ├── Analytics group      (metrics)
   └── Fraud group          (risk)
```

Each group has its own offsets. Notification being slow does not delete the event for analytics.

---

## When to use RabbitMQ

Use RabbitMQ when **one service has a job for another service**, and that job should wait if the other service is down.

Examples:

- Order created → send confirmation email (ShopSphere today)
- Payment completed → send receipt
- Order shipped → send tracking email
- Generate a PDF, resize an image, call a slow third party

Short line: **RabbitMQ is a work queue. Pick it for tasks.**

---

## When to use Kafka

Use Kafka when **many systems must read the same stream**, at high volume, and you may need to **replay** history.

Examples:

- Clickstream / `ProductViewed`
- `OrderCreated` feeding analytics, search index, fraud, and warehouse at once
- Event sourcing
- Data pipeline into a warehouse

Short line: **Kafka is a durable event log. Pick it for streams.**

ShopSphere does not have that requirement yet. We do not add Kafka because it is “more powerful.” We add it when several independent consumers need the same order history.

---

## Side-by-side

| Area | RabbitMQ | Kafka |
|---|---|---|
| What it is | Message broker with queues | Event streaming log |
| Unit | Message / work item | Event in a topic |
| ShopSphere today | `order_created` → email | Not used |
| Routing | Exchange + routing key | Topic + partition key |
| Parallelism | Competing consumers on a queue | Partitions + consumer group |
| After success | Message leaves the queue (ack) | Event stays until retention |
| Replay | Not the main design | Core design (offsets) |
| Many readers of the same event | Extra queues / fan-out setup | Natural (many consumer groups) |
| Typical scale story | Task throughput | Huge streams |
| AWS managed option | Amazon MQ (RabbitMQ) | Amazon MSK |
| UI | Management UI `:15672` | AKHQ or similar |

---

## Other brokers you will hear

- **Amazon SQS** — AWS queue. Same *kind* of problem as RabbitMQ (work waiting). Often paired with **SNS** for fan-out (one event, many queues).
- **Amazon SNS** — pub/sub notifications, not a durable log like Kafka.
- **Amazon MQ** — AWS runs RabbitMQ (or ActiveMQ) for you. That is the planned prod HA path for ShopSphere’s existing AMQP code.
- **Amazon MSK** — AWS-managed Kafka.

We will go deeper on SQS and SNS later. For ShopSphere’s current order email, the app is written for RabbitMQ, so prod HA means managed RabbitMQ, not a rewrite to SQS or Kafka.

---

## Why ShopSphere uses RabbitMQ, not Kafka

The developers already publish AMQP to `order_events` / `order.created` and consume `notification_queue`. The need is: **do this email job asynchronously and reliably.**

That is a queue. Kafka would work, but it is heavier: partitions, consumer groups, retention, ops. We do not need replay of two days of orders for one email.

Later, if ShopSphere grows analytics, fraud, and recommendations all reading `OrderCreated`, Kafka (or MSK) can sit **beside** RabbitMQ:

```text
Order service
    ├── RabbitMQ → notification email (operational work)
    └── Kafka    → business event stream (analytics, fraud, …)
```

Current stage is only the left path.

---

## Two sentences to remember

> **RabbitMQ: here is work that needs to be processed.**

> **Kafka: this event happened; keep the stream available for independent consumers.**

For ShopSphere now: RabbitMQ. For a future event platform: Kafka. Neither is universally better. The communication pattern decides.
