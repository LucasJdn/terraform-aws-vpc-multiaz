# Project 3 — Multi-AZ AWS Network Foundation (Terraform)

A modular, highly-available network foundation for a web application on AWS,
built with Terraform. This project separates network and security concerns
into independent, reusable modules connected through a root configuration.

## Architecture Overview

```
                              Internet
                                 │
                        Internet Gateway
                                 │
                    ┌────────────────────────┐
                    │     Public Route Table    │
                    └────────────────────────┘
                          │              │
                 Public Subnet A   Public Subnet B
                  (us-east-1a)      (us-east-1b)
                   NAT GW #1          NAT GW #2
                    (EIP #1)           (EIP #2)
                       │                  │
              Private Route Table    Private Route Table
                    (AZ-a)                (AZ-b)
                       │                  │
                Private Subnet A     Private Subnet B
                 (us-east-1a)         (us-east-1b)
```

Two public subnets and two private subnets are distributed across two
Availability Zones (`us-east-1a` and `us-east-1b`) inside a single VPC
(`10.2.0.0/16`).

## Design Decisions

### 1. Multi-AZ from the start

Every subnet type (public and private) exists in **two separate
Availability Zones** rather than one. This is a hard requirement for the
Application Load Balancer used in later stages of this project (an ALB
requires subnets in at least two AZs to be provisioned), and more broadly
it's the baseline expectation for any workload that needs to survive a
single AZ outage.

### 2. Dedicated CIDR range per project

This VPC uses `10.2.0.0/16`, deliberately different from the `10.1.0.0/16`
range used in the earlier single-AZ network project. Keeping non-overlapping
ranges across projects avoids conflicts if VPC Peering is ever introduced
between them, and keeps each project's address space unambiguous.

### 3. One NAT Gateway per Availability Zone (resilience over cost)

Instead of a single shared NAT Gateway, this design provisions **one NAT
Gateway per AZ**, each with its own Elastic IP. This was a deliberate
trade-off:

- **Cost**: two NAT Gateways roughly double the hourly + data-processing
  cost compared to a single shared NAT.
- **Resilience**: if one Availability Zone becomes unavailable, only the
  private subnet in that AZ loses outbound internet access. The other AZ's
  private subnet keeps working independently, because it routes through its
  own NAT Gateway in its own AZ.

For a project meant to demonstrate production-oriented practices, resilience
was prioritized over the marginal cost savings of a single NAT Gateway.

### 4. Each NAT Gateway requires its own Elastic IP

A NAT Gateway performs Source NAT (SNAT): traffic leaving a private subnet
has its source IP rewritten to the NAT Gateway's own public IP before
reaching the internet, and the NAT Gateway tracks the mapping so return
traffic reaches the correct private resource. This requires the NAT Gateway
itself to own a fixed, public IP address — which is exactly what an Elastic
IP provides. The Internet Gateway, by contrast, does not perform this kind
of translation (it only relays traffic for resources that already have a
public IP of their own), so it never needs an Elastic IP attached to it.

### 5. Route table strategy: shared for public, isolated for private

- **Public**: both public subnets share a **single** route table, since
  both need the exact same route (`0.0.0.0/0` → Internet Gateway). There's
  no reason to duplicate an identical route table per subnet.
- **Private**: each AZ has its **own** private route table, each pointing
  `0.0.0.0/0` to the NAT Gateway **in that same AZ**. This is what actually
  makes the "one NAT per AZ" resilience decision meaningful — if both
  private subnets shared one route table pointing to a single NAT, having
  two NAT Gateways would provide no benefit.

Every subnet is explicitly associated with its route table via
`aws_route_table_association` — nothing is left to the VPC's default main
route table, which only contains the implicit local route and no path to
the internet.

### 6. Security Groups: layered access, no direct public exposure to instances

Two Security Groups are used instead of one:

- **ALB Security Group**: allows inbound HTTP (port 80) from `0.0.0.0/0`.
  This is intentional — the load balancer is the only component meant to be
  reachable directly from the internet.
- **Instance Security Group**: allows inbound port 80 **only from the ALB's
  Security Group** (via `referenced_security_group_id`), not from any CIDR
  block. This means application instances cannot be reached directly by
  anyone on the internet, even if someone discovers their private IP —
  traffic must pass through the ALB first.

This is a defense-in-depth pattern: even if the ALB's routing or the
instance's application logic has a flaw, the network layer itself refuses
any inbound connection that didn't originate from the load balancer.

### 7. Modular structure: `network` and `security` as independent modules

The configuration is split into two Terraform modules under `modules/`:

```
projeto03/
├── main.tf                  # root module — calls network + security
├── modules/
│   ├── network/              # VPC, subnets, IGW, NAT, route tables
│   │   ├── main.tf
│   │   └── outputs.tf
│   └── security/             # Security Groups
│       ├── main.tf
│       └── variables.tf
```

Modules in Terraform are isolated from each other — a resource inside
`security` cannot directly reference a resource inside `network`. The
connection between them is made explicit through the root module:

- `network` exposes `vpc_id` as an **output**.
- `security` declares `vpc_id` as a required **input variable**.
- The root `main.tf` wires them together:

```hcl
module "network" {
  source = "./modules/network"
}

module "security" {
  source = "./modules/security"

  vpc_id = module.network.vpc_id
}
```

This mirrors how independent teams operate in a real organization — a
networking team's Terraform doesn't need to know anything about a security
or application team's resources beyond an agreed-upon interface (outputs in,
variables out).

### 8. Provider configuration lives only in the root module

The `provider "aws" { ... }` block is declared **only** in the root
`main.tf`, not inside the child modules. Child modules only declare which
provider they require (via `required_providers`), and inherit the actual
configured provider (region, credentials) from whichever root module calls
them. This keeps modules portable — the same `network` module could be
called again from a different root configuration targeting a different
region, without any changes inside the module itself.

## How to Run

From the `projeto03/` root directory:

```bash
terraform init
terraform plan
terraform apply
```

Expected plan output: **17 resources** to add (1 VPC, 4 subnets, 1 Internet
Gateway, 2 Elastic IPs, 2 NAT Gateways, 3 route tables, 4 route table
associations) from the `network` module, plus the Security Group resources
from the `security` module.

## Estimated Cost

The main cost driver in this project is the **two NAT Gateways** — each
billed hourly plus per-GB of data processed. This is the direct cost of the
resilience trade-off described in Decision #3. All other resources (VPC,
subnets, route tables, Internet Gateway, Security Groups) carry no
additional cost by themselves.

## Known Limitations / Pending Work

- Security Groups currently declare inbound rules only; outbound traffic
  relies on AWS's default auto-created "allow all outbound" rule rather
  than an explicit `aws_vpc_security_group_egress_rule`. Adding explicit
  egress rules is a planned improvement for auditability.
- Remote state backend (S3 + DynamoDB lock) configuration is managed via a
  separate bootstrap project and referenced here, rather than duplicated.
- This network module does not yet expose a variabilized CIDR (VPC and
  subnet ranges are currently hardcoded); parameterizing these via
  `variables.tf` is a natural next step for reusability across environments
  (dev/staging/prod).
  