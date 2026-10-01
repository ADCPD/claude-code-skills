# Mermaid — gabarits UML et pièges

## Pièges de syntaxe (cause n°1 de diagramme cassé)

- Pas de `<` `>` `(` `)` bruts dans un label de nœud `flowchart` : les entourer de guillemets — `A["Handler (sync)"]`.
- `classDiagram` : les génériques s'écrivent `List~Payment~`, jamais `List<Payment>`.
- Un nom de classe ne peut pas contenir `\`. Utiliser le nom court + note pour le namespace.
- `sequenceDiagram` : `participant P as Nom Lisible` puis toujours référencer `P`.
- Les commentaires Mermaid commencent par `%%` en début de ligne.
- Un `note for X` en `classDiagram` doit suivre la déclaration de `X`.

## Class diagram

```mermaid
classDiagram
    direction LR

    class Payment {
        <<entity>>
        -PaymentId id
        -Money amount
        -PaymentStatus status
        +capture(CapturedAt at) void
        +isRefundable() bool
    }

    class Money {
        <<value object>>
        -int amountInCents
        -Currency currency
        +add(Money other) Money
    }

    class PaymentStatus {
        <<enumeration>>
        PENDING
        CAPTURED
        REFUNDED
    }

    class PaymentRepository {
        <<interface>>
        +findById(PaymentId id) Payment
        +save(Payment payment) void
    }

    class DoctrinePaymentRepository {
        +findById(PaymentId id) Payment
        +save(Payment payment) void
    }

    Payment *-- Money : composition
    Payment --> PaymentStatus
    DoctrinePaymentRepository ..|> PaymentRepository : implements
    note for DoctrinePaymentRepository "App\\Infrastructure\\Doctrine"
```

Relations : `<|--` héritage, `..|>` implémentation, `*--` composition, `o--` agrégation, `-->` association dirigée, `..>` dépendance (à réserver aux liens déduits, annotés).

## Sequence diagram

```mermaid
sequenceDiagram
    autonumber
    actor Client
    participant C as PaymentController
    participant H as CreatePaymentHandler
    participant R as PaymentRepository
    participant P as PayoneerClient

    Client->>C: POST /payments
    C->>H: handle(CreatePaymentCommand)
    H->>R: save(Payment)
    R-->>H: Payment
    H->>P: submitPayout(payload)
    alt réponse 2xx
        P-->>H: PayoutId
        H->>R: save(Payment captured)
    else erreur externe
        P--)H: PayoneerException
        H-->>C: PaymentFailed
    end
    C-->>Client: 201 Created
```

`->>` appel sync, `-->>` retour, `--)` async/événement, `activate`/`deactivate` uniquement si la durée de vie apporte une information.

## Component diagram

```mermaid
flowchart TB
    subgraph Domain
        E[Payment]
        RI[/PaymentRepository interface/]
    end
    subgraph Application
        H[CreatePaymentHandler]
    end
    subgraph Infrastructure
        DR[DoctrinePaymentRepository]
        PC[PayoneerClient]
        DB[(payment DB)]
        MQ[[messenger: payment_async]]
    end

    H --> RI
    H --> E
    DR -.implements.-> RI
    DR --> DB
    H --> PC
    H --> MQ
```

Formes : `[(...)]` base de données, `[[...]]` file/bus, `[/.../]` interface, `((...))` acteur externe.

## ERD

```mermaid
erDiagram
    PAYMENT ||--o{ PAYMENT_LINE : contains
    PAYMENT }o--|| PAYEE : "belongs to"
    PAYMENT {
        uuid id PK
        bigint amount_in_cents
        char currency
        varchar status
        uuid payee_id FK
    }
```

Cardinalités : `||` exactement un, `o{` zéro ou plusieurs, `|{` un ou plusieurs.

## State diagram

```mermaid
stateDiagram-v2
    [*] --> PENDING
    PENDING --> CAPTURED : capture()
    PENDING --> CANCELLED : cancel()
    CAPTURED --> REFUNDED : refund()
    REFUNDED --> [*]
    CANCELLED --> [*]
```

Nommer les transitions avec la méthode ou la transition Symfony Workflow réelle, pas une paraphrase.

## React (pas de classDiagram)

```mermaid
flowchart TD
    P[PaymentPage] -->|payments| L[PaymentList]
    L -->|payment| I[PaymentRow]
    I -->|onRefund| L
    L -->|onRefund| P
    P --> H{{usePayments}}
    H --> API[(GET /api/payments)]
```

Flèche descendante = props, flèche remontante = callback, `{{...}}` = hook.
