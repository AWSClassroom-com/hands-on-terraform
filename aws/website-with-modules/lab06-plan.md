# Lab 06 — Refactor to Modules: Planning Document

> **Audience**: Instructor planning guide. Not student-facing.
> **Prerequisite state**: Students have completed Labs 01–05 in a single flat folder:
> `s3-bucket → vpc → security-group → language → website`
> All resources are live and managed in one Terraform state file.
> **Continuity**: Students stay in the same working folder and use the same backend/state from prior labs. This lab is refactor-only — no teardown, no new backend, no new workspace.

---

## Why This Design

The most common failure in refactor labs is treating module extraction like a greenfield rebuild. That leads to unnecessary destroy/recreate operations and hides the real learning objective, which is state-preserving architecture change. This plan keeps students anchored to one continuous environment and reinforces the sequence they must internalize:

1. Refactor code structure.
2. Map old resource addresses to new addresses (`moved` blocks) **immediately, in the same task**.
3. Run `terraform plan` and verify no unintended add/change/destroy.
4. Continue only when plan is clean.

### Core Rules (Must Stay True for Entire Lab)

1. Students stay in the same folder used at the end of the previous lab.
2. Students keep the same backend/state. Do **not** use a backend-disabled workflow.
3. Validation after each task is `terraform plan` (not `terraform init -backend=false` / `terraform validate`).
4. `moved` blocks are added in the same task that introduces the address change — never deferred.
5. `moved` blocks are migration scaffolding and **must** be removed after convergence.
6. Load balancer DNS ownership stays in the load balancer module and is re-exposed via root output.
7. Never use `user01` in instructor test automation (use unique run tags).

---

## Table of Contents

1. [Existing Resource Inventory](#1-existing-resource-inventory)
2. [Design Decisions](#2-design-decisions)
3. [Directory Structure](#3-directory-structure)
4. [Phase 1 — Pure Refactor Into Modules](#4-phase-1--pure-refactor-into-modules)
5. [Phase 2 — Optimize to Show Module Power](#5-phase-2--optimize-to-show-module-power)
6. [Phase 3 — Optional Challenge: Registry Module](#6-phase-3--optional-challenge-registry-module)
7. [Complete Moved Blocks Reference](#7-complete-moved-blocks-reference)
8. [Variable & Output Contract Reference](#8-variable--output-contract-reference)
9. [Validation Checklist](#9-validation-checklist)

---

## 1. Existing Resource Inventory

These are the resources in state after the `website` lab (the merged flat configuration).
Every resource must be accounted for in the module refactor.

### S3 Bucket (from Lab 01 — `bucket.tf`)
| # | Resource Address | Type |
|---|---|---|
| 1 | `aws_s3_bucket.bucket` | `aws_s3_bucket` |
| 2 | `aws_s3_bucket_ownership_controls.this` | `aws_s3_bucket_ownership_controls` |
| 3 | `aws_s3_bucket_public_access_block.this` | `aws_s3_bucket_public_access_block` |
| 4 | `aws_s3_bucket_versioning.versioning` | `aws_s3_bucket_versioning` |
| 5 | `aws_s3_bucket_server_side_encryption_configuration.encryption` | `aws_s3_bucket_server_side_encryption_configuration` |

### Networking (from Labs 02 + 04 — `custom-vpc.tf`, `locals.tf`, `private-network.tf`)
| # | Resource Address | Type | Notes |
|---|---|---|---|
| 6 | `aws_vpc.custom-vpc` | `aws_vpc` | DNS hostnames + DNS support enabled |
| 7 | `aws_subnet.public_subnets` | `aws_subnet` | `for_each` keyed by AZ name |
| 8 | `aws_internet_gateway.igw` | `aws_internet_gateway` | |
| 9 | `aws_nat_gateway.ngw` | `aws_nat_gateway` | Regional, public connectivity |
| 10 | `aws_route_table.public_rt` | `aws_route_table` | Routes to IGW |
| 11 | `aws_route_table_association.public_assoc` | `aws_route_table_association` | `for_each` matching public_subnets |
| 12 | `aws_subnet.private_subnets` | `aws_subnet` | `count` by AZ index |
| 13 | `aws_route_table.private_rt` | `aws_route_table` | Routes to NAT GW |
| 14 | `aws_route_table_association.private_assoc` | `aws_route_table_association` | `count` matching private_subnets |

**Data sources** (not stateful — no moved blocks needed):
- `data.aws_availability_zones.available`
- `locals.public_subnets` (derived map of AZ→CIDR)

### Security Groups (from Labs 03 + 05 — `sec-groups.tf`)
| # | Resource Address | Type | Notes |
|---|---|---|---|
| 15 | `aws_security_group.allow-http-ssh` | `aws_security_group` | App instances SG |
| 16 | `aws_vpc_security_group_ingress_rule.allow-http-ipv4` | Ingress rule | HTTP from ALB SG only |
| 17 | `aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` | Ingress rule | SSH from 0.0.0.0/0 |
| 18 | `aws_vpc_security_group_egress_rule.allow-all-outbound` | Egress rule | All outbound |
| 19 | `aws_security_group.alb_sg` | `aws_security_group` | ALB SG (internet-facing) |
| 20 | `aws_vpc_security_group_ingress_rule.alb_http_in` | Ingress rule | HTTP from 0.0.0.0/0 |
| 21 | `aws_vpc_security_group_egress_rule.alb_all_out` | Egress rule | All outbound |

**Cross-reference**: Resource #16 (`allow-http-ipv4`) uses `referenced_security_group_id` pointing to resource #19 (`alb_sg`). This means the app SG and ALB SG are coupled.

### Load Balancer (from Lab 05 — `load-balancer.tf`)
| # | Resource Address | Type |
|---|---|---|
| 22 | `aws_lb.web_alb` | `aws_lb` (ALB) |
| 23 | `aws_lb_target_group.web_tg` | `aws_lb_target_group` |
| 24 | `aws_lb_listener.web_listener` | `aws_lb_listener` |

### Autoscaling Group (from Lab 05 — `autoscaling-group.tf`)
| # | Resource Address | Type |
|---|---|---|
| 25 | `aws_launch_template.web_template` | `aws_launch_template` |
| 26 | `aws_autoscaling_group.web_asg` | `aws_autoscaling_group` |

**Total: 26 managed resources + 1 data source**

---

## 2. Design Decisions

### Same folder, same state, plan-driven validation
Students do **not** create a new directory or switch backends. They continue in the same folder they finished Lab 05 in. Every validation gate is `terraform plan` (not `terraform init -backend=false` / `terraform validate`). This ensures students see real state moves reflected in the plan.

### `moved` blocks are in-task, not deferred
Each task that introduces an address change must include the corresponding `moved` blocks and a `terraform plan` gate. This reinforces the refactor loop and catches mistakes early. Every task ends with a plan gate, so coverage is continuously verified — no separate audit step is needed.

### Mandatory moved cleanup after convergence
`moved` blocks are migration scaffolding. After the state converges (apply + clean plan), they **must** be removed. Task 8 is mandatory, not optional.

### Why keep all networking in one module for Phase 1?
Public subnets use `for_each` (keyed by AZ name: `aws_subnet.public_subnets["us-east-2a"]`).
Private subnets use `count` (indexed: `aws_subnet.private_subnets[0]`).

A single generic "subnet" module called twice would require both calls to use the same iteration strategy. Changing `count` to `for_each` (or vice versa) changes state addresses, which means **additional** moved blocks and potential confusion. In Phase 1 we keep both subnet types inside one `networking` module to avoid this. Phase 2 standardizes on `for_each` for both and splits them out.

### Why keep both security groups in one module for Phase 1?
The app SG's HTTP ingress rule references the ALB SG's ID (`referenced_security_group_id`). Keeping both in one module avoids a circular dependency and simplifies wiring. Phase 2 splits them with a two-pass approach: create ALB SG first, pass its ID to the app SG module.

### Where does `install_space_invaders.sh` live?
The flat config uses `filebase64("${path.module}/install_space_invaders.sh")`. When the launch template moves into a module, `path.module` points to the module directory. Two options:

- **Option A**: Put the script in `modules/autoscaling-group/` — simple but couples the module to this specific app.
- **Option B**: Pass `user_data_base64` as a variable from root — the root calls `filebase64()` and passes the result. Module stays generic.

**Recommendation**: Option B for better module reusability (and it teaches separation of concerns). The script stays at the root level.

### Variable naming: `instance_count_max` validation
The flat `website/variables.tf` intentionally has `instance_count_max >= 3` while `terraform.tfvars` sets it to `2`. This is a deliberate teaching moment (students hit the error, then fix to `4`). In the modules version, `terraform.tfvars` will set `instance_count_max = 4`.

### Old `moved` blocks from Lab 04 (language)
The flat config's `custom-vpc.tf` has moved blocks from the `subnet-a → public_subnets["<az>"]` migration. Those are already applied in state and have no effect. **Do not carry them into the modules version.** Only new flat→module moved blocks are needed.

### Remove obsolete root variables
`public_subnet_a_name` and `public_subnet_a_cidr` are vestigial from Lab 02 (single subnet). They were superseded by the dynamic subnets in Lab 04 and are not consumed by any module. They should be **removed** from root `variables.tf` and `terraform.tfvars` as part of Task 6. This teaches students that refactoring includes tech-debt cleanup, not just file movement.

### Consumer rewiring during incremental extraction
When resources are extracted into a module one group at a time (Tasks 2–6), the flat files being deleted may contain resources referenced by other flat files that still remain. For example, after Task 3 moves networking into a module and deletes `custom-vpc.tf`, the remaining `sec-groups.tf` still references `aws_vpc.custom-vpc.id` — which no longer exists as a flat resource. Each extraction task must therefore: (a) delete the flat files whose resources moved to the module, and (b) update remaining flat files to reference the corresponding module output instead (`aws_vpc.custom-vpc.id` → `module.networking.vpc_id`). This is safe because the module output resolves to the same underlying value, so `terraform plan` stays clean. The same pattern applies in Phase 2 when replacing one module with another — downstream module calls must be updated to reference the new module's outputs.

---

## 3. Directory Structure

### Phase 1 End State

```
website-with-modules/       (same folder as prior labs)
├── modules/
│   ├── s3-bucket/
│   │   ├── main.tf              # 5 resources
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── networking/
│   │   ├── main.tf              # 9 resources + data source + locals
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── security-groups/
│   │   ├── main.tf              # 7 resources (2 SGs + 5 rules)
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── load-balancer/
│   │   ├── main.tf              # 3 resources
│   │   ├── variables.tf
│   │   └── output.tf
│   └── autoscaling-group/
│       ├── main.tf              # 2 resources
│       ├── variables.tf
│       └── output.tf
├── install_space_invaders.sh
├── provider.tf
├── main.tf                      # Module calls
├── variables.tf                 # Root variables (obsolete ones removed)
├── terraform.tfvars
├── output.tf
└── moved.tf                     # 26 moved blocks (removed after Task 8)
```

### Phase 2 End State

```
website-with-modules/
├── modules/
│   ├── s3-bucket/                # Unchanged from Phase 1
│   │   └── ...
│   ├── vpc/                      # NEW: Just core VPC + IGW + NAT GW
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── subnets/                  # NEW: Generic — called twice (public + private)
│   │   ├── main.tf              # Uses for_each for both
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── security-group/           # RENAMED: Generic — called per SG
│   │   ├── main.tf              # 1 SG + dynamic rules
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── load-balancer/            # Unchanged from Phase 1
│   │   └── ...
│   └── autoscaling-group/        # Unchanged from Phase 1
│       └── ...
├── install_space_invaders.sh
├── provider.tf
├── main.tf                       # Updated module calls
├── variables.tf
├── terraform.tfvars
├── output.tf
└── moved.tf                      # Updated with Phase 2 moves (removed after final cleanup)
```

### Phase 3 End State (Optional Challenge)

```
website-with-modules/
├── modules/
│   ├── s3-bucket/                # Unchanged from Phase 2
│   │   └── ...
│   ├── vpc/                      # Unchanged from Phase 2
│   │   └── ...
│   ├── subnets/                  # Unchanged from Phase 2
│   │   └── ...
│   ├── load-balancer/            # Unchanged from Phase 2
│   │   └── ...
│   └── autoscaling-group/        # Unchanged from Phase 2
│       └── ...
│   (security-group/ module removed — replaced by registry module)
├── main.tf                       # Registry module calls replace local SG module
├── moved.tf                      # Maps Phase 2 custom SG → registry internal addresses
└── (all other root files unchanged from Phase 2)
```

---

## 4. Phase 1 — Pure Refactor Into Modules

**Goal**: Reorganize the existing flat resources into modules with zero infrastructure changes. Every resource keeps its exact same configuration. Only the Terraform address changes (e.g., `aws_vpc.custom-vpc` → `module.networking.aws_vpc.custom-vpc`). Students stay in the same folder and use the same backend throughout.

---

### Task 1: Baseline and Migration Metadata Reset

Before any refactoring begins, students must confirm they are starting from a clean, known-good state. This task establishes that discipline: verify the existing deployment is healthy, remove any leftover migration artifacts from prior labs, and confirm a clean plan. Without this step, any errors introduced during refactoring become much harder to diagnose.

**What students do**:
1. Confirm they are in the same folder/state chain from the prior lab.
2. If stale `moved` blocks exist from prior lab experiments (e.g., the Lab 04 subnet-a migration), move them out of active config (e.g., rename to `moved.tf.bak` or delete them).
3. Run `terraform plan`.
4. Require clean plan (no create/change/destroy from unrelated drift) before moving forward.

**Validation**:
```bash
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."
```

If plan is not clean:
- **Stop the lab.**
- Resolve baseline drift first.

**Teaching points**:
- This lab is refactor-only, not redeploy.
- Students must understand that a clean starting baseline is a prerequisite for a safe refactor.
- Old `moved` blocks from prior labs are already applied in state and will not affect this lab, but removing them reduces confusion.

**Task conclusion**:
Students begin from a known-good baseline and understand that refactoring should preserve infrastructure, not recreate it.

---

### Task 2: Build the S3 Bucket Module (+ Moved Blocks)

The S3 bucket is the simplest resource group to modularize — five resources with no cross-dependencies on other modules. Starting here lets students learn the full module-creation workflow (create directory, move resources, wire variables/outputs, add moved blocks, verify with plan) on the easiest target before tackling more complex resource groups. It also introduces output ownership: the bucket name originates inside the module, so the module owns that output and root re-exposes it.

**What students do**:

1. **Create `modules/s3-bucket/main.tf`** — move these 5 resources verbatim from `bucket.tf`:
   | # | Resource | Source File |
   |---|---|---|
   | 1 | `aws_s3_bucket.bucket` | `bucket.tf` |
   | 2 | `aws_s3_bucket_ownership_controls.this` | `bucket.tf` |
   | 3 | `aws_s3_bucket_public_access_block.this` | `bucket.tf` |
   | 4 | `aws_s3_bucket_versioning.versioning` | `bucket.tf` |
   | 5 | `aws_s3_bucket_server_side_encryption_configuration.encryption` | `bucket.tf` |

2. **Create `modules/s3-bucket/variables.tf`** — none required (all values are hardcoded as in the original).

3. **Create `modules/s3-bucket/output.tf`**:
   | Output | Value |
   |---|---|
   | `bucket_name` | `aws_s3_bucket.bucket.id` |

4. **Add module call** to root `main.tf`:
   ```hcl
   module "s3_bucket" {
     source = "./modules/s3-bucket"
   }
   ```

5. **Add root output** to `output.tf`:
   ```hcl
   output "bucket_name" {
     description = "The name of the S3 bucket to use for remote state"
     value       = module.s3_bucket.bucket_name
   }
   ```

6. **Delete flat file**: `bucket.tf` (no remaining flat files reference S3 resources, so no rewiring needed).

7. **Add moved blocks** to `moved.tf` (5 entries):
   | From | To |
   |---|---|
   | `aws_s3_bucket.bucket` | `module.s3_bucket.aws_s3_bucket.bucket` |
   | `aws_s3_bucket_ownership_controls.this` | `module.s3_bucket.aws_s3_bucket_ownership_controls.this` |
   | `aws_s3_bucket_public_access_block.this` | `module.s3_bucket.aws_s3_bucket_public_access_block.this` |
   | `aws_s3_bucket_versioning.versioning` | `module.s3_bucket.aws_s3_bucket_versioning.versioning` |
   | `aws_s3_bucket_server_side_encryption_configuration.encryption` | `module.s3_bucket.aws_s3_bucket_server_side_encryption_configuration.encryption` |

8. **Run `terraform plan`**.

**Plan gate**:
```bash
terraform plan
# Expected: S3 resources show "has moved to" annotations
# Expected: 0 to add, 0 to change, 0 to destroy
```

**Teaching points**:
- Simplest possible module — no inputs, one output.
- Introduces output ownership: the module owns `bucket_name` and root re-exposes it. This pattern repeats with the load-balancer module's `alb_dns_name` in Task 5.
- Shows how `module.X.output_name` works.
- The S3 bucket was the first thing ever created and is still here.
- `moved` blocks are added **now**, not deferred to a later task. This is the migration loop: refactor → map → plan → verify.

**Task conclusion**:
Students practice the migration loop on a small, low-risk slice and gain confidence with `moved` block syntax before tackling more complex modules.

---

### Task 3: Build the Networking Module (+ Moved Blocks)

Networking is the largest resource group (9 resources plus a data source and locals). In Phase 1 we keep all networking — VPC, subnets, gateways, route tables — in a single module to avoid changing the iteration strategy (`count` vs `for_each`). This task also introduces consumer rewiring: once the flat networking files are deleted, the remaining flat files (`sec-groups.tf`, `load-balancer.tf`, `autoscaling-group.tf`) still reference resources like `aws_vpc.custom-vpc.id` that no longer exist at root scope. Students must update those references to use module outputs instead. This is the pattern they will repeat in every subsequent extraction task.

**What students do**:

1. **Create `modules/networking/main.tf`** — move these resources verbatim:
   | # | Resource | Source File |
   |---|---|---|
   | 1 | `data.aws_availability_zones.available` | `locals.tf` |
   | 2 | `locals { public_subnets = ... }` | `locals.tf` |
   | 3 | `aws_vpc.custom-vpc` | `custom-vpc.tf` |
   | 4 | `aws_subnet.public_subnets` (for_each) | `custom-vpc.tf` |
   | 5 | `aws_internet_gateway.igw` | `custom-vpc.tf` |
   | 6 | `aws_nat_gateway.ngw` | `custom-vpc.tf` |
   | 7 | `aws_route_table.public_rt` | `custom-vpc.tf` |
   | 8 | `aws_route_table_association.public_assoc` (for_each) | `custom-vpc.tf` |
   | 9 | `aws_subnet.private_subnets` (count) | `private-network.tf` |
   | 10 | `aws_route_table.private_rt` | `private-network.tf` |
   | 11 | `aws_route_table_association.private_assoc` (count) | `private-network.tf` |

   > **Do NOT copy** the old `moved` blocks from `custom-vpc.tf` (the `subnet-a → public_subnets` ones). Those are already applied.

2. **Create `modules/networking/variables.tf`**:
   | Variable | Type | Description |
   |---|---|---|
   | `vpc_cidr` | `string` | CIDR block for the VPC |
   | `vpc_name` | `string` | Name of the VPC |
   | `route_table_name` | `string` | Name of the public route table |

3. **Create `modules/networking/output.tf`**:
   | Output | Value | Consumed By |
   |---|---|---|
   | `vpc_id` | `aws_vpc.custom-vpc.id` | security_groups, load_balancer |
   | `public_subnet_ids` | `values(aws_subnet.public_subnets)[*].id` | load_balancer |
   | `private_subnet_ids` | `aws_subnet.private_subnets[*].id` | autoscaling_group |

4. **Add module call** to root `main.tf`:
   ```hcl
   module "networking" {
     source = "./modules/networking"

     vpc_cidr         = var.vpc_cidr
     vpc_name         = var.vpc_name
     route_table_name = var.route_table_name
   }
   ```

5. **Delete flat files**: `custom-vpc.tf`, `locals.tf`, `private-network.tf`.

6. **Rewire consumer references** in remaining flat files:
   | File | Old Reference | New Reference |
   |---|---|---|
   | `sec-groups.tf` | `aws_vpc.custom-vpc.id` (×2, both SG blocks) | `module.networking.vpc_id` |
   | `load-balancer.tf` | `aws_vpc.custom-vpc.id` | `module.networking.vpc_id` |
   | `load-balancer.tf` | `values(aws_subnet.public_subnets)[*].id` | `module.networking.public_subnet_ids` |
   | `autoscaling-group.tf` | `aws_subnet.private_subnets[*].id` | `module.networking.private_subnet_ids` |

7. **Add moved blocks** to `moved.tf` (9 entries):
   | From | To |
   |---|---|
   | `aws_vpc.custom-vpc` | `module.networking.aws_vpc.custom-vpc` |
   | `aws_subnet.public_subnets` | `module.networking.aws_subnet.public_subnets` |
   | `aws_internet_gateway.igw` | `module.networking.aws_internet_gateway.igw` |
   | `aws_nat_gateway.ngw` | `module.networking.aws_nat_gateway.ngw` |
   | `aws_route_table.public_rt` | `module.networking.aws_route_table.public_rt` |
   | `aws_route_table_association.public_assoc` | `module.networking.aws_route_table_association.public_assoc` |
   | `aws_subnet.private_subnets` | `module.networking.aws_subnet.private_subnets` |
   | `aws_route_table.private_rt` | `module.networking.aws_route_table.private_rt` |
   | `aws_route_table_association.private_assoc` | `module.networking.aws_route_table_association.private_assoc` |

8. **Run `terraform plan`**.

**Plan gate**:
```bash
terraform plan
# Expected: networking resources show "has moved to" annotations
# Expected: 0 to add, 0 to change, 0 to destroy
```

**Teaching points**:
- Largest module — shows how to wrap complex networking.
- Data sources and locals move into the module (they're internal implementation details).
- Outputs shape the module's public API — only expose what other modules need.
- The `for_each` and `count` patterns are preserved exactly as-is.
- **Consumer rewiring**: Extracting a module isn't just moving files — you must update every remaining file that referenced the moved resources. The module output resolves to the same value, so plan stays clean.

**Task conclusion**:
Students learn to preserve behavior while changing structure, and see how iterator choice (`for_each` vs `count`) affects address stability.

---

### Task 4: Build the Security Groups Module (+ Moved Blocks)

This module introduces cross-module wiring: the `module "security_groups"` call passes `module.networking.vpc_id` as an input variable — the first time a module call references another module's output. It also introduces a deliberate design decision: the app SG's HTTP ingress rule references the ALB SG's ID, so the two security groups are internally coupled. Keeping both in one module for Phase 1 avoids a circular dependency. The consumer rewiring pattern from Task 3 continues — `load-balancer.tf` and `autoscaling-group.tf` must switch their SG references to module outputs.

**What students do**:

1. **Create `modules/security-groups/main.tf`** — move these resources verbatim:
   | # | Resource | Source File |
   |---|---|---|
   | 1 | `aws_security_group.allow-http-ssh` | `sec-groups.tf` |
   | 2 | `aws_vpc_security_group_ingress_rule.allow-http-ipv4` | `sec-groups.tf` |
   | 3 | `aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` | `sec-groups.tf` |
   | 4 | `aws_vpc_security_group_egress_rule.allow-all-outbound` | `sec-groups.tf` |
   | 5 | `aws_security_group.alb_sg` | `sec-groups.tf` |
   | 6 | `aws_vpc_security_group_ingress_rule.alb_http_in` | `sec-groups.tf` |
   | 7 | `aws_vpc_security_group_egress_rule.alb_all_out` | `sec-groups.tf` |

2. **Create `modules/security-groups/variables.tf`**:
   | Variable | Type | Description |
   |---|---|---|
   | `vpc_id` | `string` | VPC ID to create security groups in |
   | `security_group_name` | `string` | Name of the application security group |
   | `account` | `string` | Account/user name prefix |

3. **Create `modules/security-groups/output.tf`**:
   | Output | Value | Consumed By |
   |---|---|---|
   | `app_sg_id` | `aws_security_group.allow-http-ssh.id` | autoscaling_group |
   | `alb_sg_id` | `aws_security_group.alb_sg.id` | load_balancer |

4. **Add module call** to root `main.tf`:
   ```hcl
   module "security_groups" {
     source = "./modules/security-groups"

     vpc_id              = module.networking.vpc_id
     security_group_name = var.security_group_name
     account             = var.account
   }
   ```

5. **Delete flat file**: `sec-groups.tf`.

6. **Rewire consumer references** in remaining flat files:
   | File | Old Reference | New Reference |
   |---|---|---|
   | `load-balancer.tf` | `aws_security_group.alb_sg.id` | `module.security_groups.alb_sg_id` |
   | `autoscaling-group.tf` | `aws_security_group.allow-http-ssh.id` | `module.security_groups.app_sg_id` |

7. **Add moved blocks** to `moved.tf` (7 entries):
   | From | To |
   |---|---|
   | `aws_security_group.allow-http-ssh` | `module.security_groups.aws_security_group.allow-http-ssh` |
   | `aws_vpc_security_group_ingress_rule.allow-http-ipv4` | `module.security_groups.aws_vpc_security_group_ingress_rule.allow-http-ipv4` |
   | `aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` | `module.security_groups.aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` |
   | `aws_vpc_security_group_egress_rule.allow-all-outbound` | `module.security_groups.aws_vpc_security_group_egress_rule.allow-all-outbound` |
   | `aws_security_group.alb_sg` | `module.security_groups.aws_security_group.alb_sg` |
   | `aws_vpc_security_group_ingress_rule.alb_http_in` | `module.security_groups.aws_vpc_security_group_ingress_rule.alb_http_in` |
   | `aws_vpc_security_group_egress_rule.alb_all_out` | `module.security_groups.aws_vpc_security_group_egress_rule.alb_all_out` |

8. **Run `terraform plan`**.

**Plan gate**:
```bash
terraform plan
# Expected: SG resources show "has moved to" annotations
# Expected: 0 to add, 0 to change, 0 to destroy
```

**Teaching points**:
- Cross-module references: `module.networking.vpc_id` flows into this module.
- Both SGs stay together because the app SG's HTTP rule references the ALB SG — internal coupling that doesn't need to leak out.
- The module exposes both SG IDs so downstream modules can pick what they need.
- **Consumer rewiring**: `load-balancer.tf` and `autoscaling-group.tf` still reference SG resources directly — those references must switch to module outputs.

**Task conclusion**:
Students see the value of grouping tightly coupled resources to reduce root clutter and cross-module coupling.

---

### Task 5: Build the Load Balancer Module (+ Moved Blocks)

The load balancer module call wires inputs from two different modules — subnet IDs from networking and the ALB SG ID from security groups — showing how the dependency graph grows as modules compose. Like the S3 module in Task 2, the LB module owns an output (the ALB DNS name) that root re-exposes. Only `autoscaling-group.tf` remains as a flat file after this extraction.

**What students do**:

1. **Create `modules/load-balancer/main.tf`** — move these resources verbatim:
   | # | Resource | Source File |
   |---|---|---|
   | 1 | `aws_lb.web_alb` | `load-balancer.tf` |
   | 2 | `aws_lb_target_group.web_tg` | `load-balancer.tf` |
   | 3 | `aws_lb_listener.web_listener` | `load-balancer.tf` |

   > **Important change**: The ALB's `subnets` attribute in the flat config is `values(aws_subnet.public_subnets)[*].id`. In the module, subnet IDs arrive as a list variable, so change to `var.public_subnet_ids`.

2. **Create `modules/load-balancer/variables.tf`**:
   | Variable | Type | Description |
   |---|---|---|
   | `account` | `string` | Account/user name prefix |
   | `vpc_id` | `string` | VPC ID for the target group |
   | `alb_sg_id` | `string` | Security group ID for the ALB |
   | `public_subnet_ids` | `list(string)` | List of public subnet IDs for the ALB |

3. **Create `modules/load-balancer/output.tf`**:
   | Output | Value | Consumed By |
   |---|---|---|
   | `alb_dns_name` | `aws_lb.web_alb.dns_name` | root output |
   | `target_group_arn` | `aws_lb_target_group.web_tg.arn` | autoscaling_group |

4. **Add module call** to root `main.tf`:
   ```hcl
   module "load_balancer" {
     source = "./modules/load-balancer"

     account           = var.account
     vpc_id            = module.networking.vpc_id
     alb_sg_id         = module.security_groups.alb_sg_id
     public_subnet_ids = module.networking.public_subnet_ids
   }
   ```

5. **Add root output** (LB module owns this output, root re-exposes it):
   ```hcl
   output "load_balancer_dns" {
     value = module.load_balancer.alb_dns_name
   }
   ```

6. **Delete flat file**: `load-balancer.tf`.

7. **Rewire consumer references** in the remaining flat file:
   | File | Old Reference | New Reference |
   |---|---|---|
   | `autoscaling-group.tf` | `aws_lb_target_group.web_tg.arn` | `module.load_balancer.target_group_arn` |

8. **Add moved blocks** to `moved.tf` (3 entries):
   | From | To |
   |---|---|
   | `aws_lb.web_alb` | `module.load_balancer.aws_lb.web_alb` |
   | `aws_lb_target_group.web_tg` | `module.load_balancer.aws_lb_target_group.web_tg` |
   | `aws_lb_listener.web_listener` | `module.load_balancer.aws_lb_listener.web_listener` |

9. **Run `terraform plan`**.

**Plan gate**:
```bash
terraform plan
# Expected: LB resources show "has moved to" annotations
# Expected: 0 to add, 0 to change, 0 to destroy
```

**Teaching points**:
- Module consumes outputs from both `networking` and `security_groups` — shows the dependency graph.
- The `subnets` line is the one place where module code differs from the flat original (list is pre-computed by the networking module's output).
- The LB module owns the ALB DNS output; root re-exposes it. This is clean module contract design.
- **Consumer rewiring**: `autoscaling-group.tf` is the last remaining flat resource file and needs its target group reference updated. After Task 6 extracts the ASG, no flat resource files will remain.

**Task conclusion**:
Students learn module contract design and output ownership boundaries. The LB module owns `alb_dns_name` and downstream consumers reference it through the root output.

---

### Task 6: Build the Autoscaling Group Module, Remove Dead Inputs (+ Moved Blocks)

The final module extraction is also the most complex module call — it wires inputs from three other modules (networking, security groups, and load balancer). With `autoscaling-group.tf` gone, no flat resource files remain and consumer rewiring is complete. This task also introduces refactoring discipline beyond file movement: two root variables (`public_subnet_a_name` and `public_subnet_a_cidr`) carried forward from earlier labs are consumed by nothing. Removing them teaches students that refactoring includes tech-debt cleanup.

**What students do**:

1. **Create `modules/autoscaling-group/main.tf`** — move these resources verbatim:
   | # | Resource | Source File |
   |---|---|---|
   | 1 | `aws_launch_template.web_template` | `autoscaling-group.tf` |
   | 2 | `aws_autoscaling_group.web_asg` | `autoscaling-group.tf` |

   > **Important changes** in module `main.tf` vs flat original:
   > - `user_data = filebase64(...)` → `user_data = var.user_data_base64` (root passes it in)
   > - `security_groups = [aws_security_group.allow-http-ssh.id]` → `security_groups = [var.app_sg_id]`
   > - `vpc_zone_identifier = aws_subnet.private_subnets[*].id` → `vpc_zone_identifier = var.private_subnet_ids`
   > - `target_group_arns = [aws_lb_target_group.web_tg.arn]` → `target_group_arns = [var.target_group_arn]`
   > - `image_id = var.image_id[var.region]` → `image_id = var.image_id` (root resolves the map lookup)

2. **Create `modules/autoscaling-group/variables.tf`**:
   | Variable | Type | Description |
   |---|---|---|
   | `account` | `string` | Account/user name prefix |
   | `image_id` | `string` | AMI ID (already resolved by root) |
   | `instance_type` | `string` | EC2 instance type (default `t3.micro`) |
   | `instance_count_min` | `number` | Minimum ASG size (default 1) |
   | `instance_count_max` | `number` | Maximum ASG size (default 2) |
   | `user_data_base64` | `string` | Base64-encoded user data script |
   | `app_sg_id` | `string` | Security group ID for instances |
   | `private_subnet_ids` | `list(string)` | Private subnet IDs for ASG placement |
   | `target_group_arn` | `string` | ALB target group ARN |

3. **Create `modules/autoscaling-group/output.tf`** — none needed (no downstream consumers).

4. **Add module call** to root `main.tf`:
   ```hcl
   module "autoscaling_group" {
     source = "./modules/autoscaling-group"

     account            = var.account
     image_id           = var.image_id[var.region]
     instance_type      = var.instance_type
     instance_count_min = var.instance_count_min
     instance_count_max = var.instance_count_max
     user_data_base64   = filebase64("${path.module}/install_space_invaders.sh")
     app_sg_id          = module.security_groups.app_sg_id
     private_subnet_ids = module.networking.private_subnet_ids
     target_group_arn   = module.load_balancer.target_group_arn
   }
   ```

5. **Delete flat file**: `autoscaling-group.tf` (last flat resource file — no remaining files to rewire).

6. **Remove dead root variables** (no module consumes these):
   | Variable | File | Action |
   |---|---|---|
   | `public_subnet_a_name` | `variables.tf` + `terraform.tfvars` | Delete both |
   | `public_subnet_a_cidr` | `variables.tf` + `terraform.tfvars` | Delete both |

7. **Add moved blocks** to `moved.tf` (2 entries):
   | From | To |
   |---|---|
   | `aws_launch_template.web_template` | `module.autoscaling_group.aws_launch_template.web_template` |
   | `aws_autoscaling_group.web_asg` | `module.autoscaling_group.aws_autoscaling_group.web_asg` |

8. **Run `terraform plan`**.

**Plan gate**:
```bash
terraform plan
# Expected: ASG resources show "has moved to" annotations
# Expected: 0 to add, 0 to change, 0 to destroy
# Expected: No warnings about undeclared variables
```

**Teaching points**:
- Most complex module call — receives inputs from 3 other modules.
- `image_id` map lookup happens at root (module gets a simple string). This is a design choice: root knows the region, module doesn't need to.
- `user_data_base64` comes from root's `filebase64()` call — keeps the module generic.
- `path.module` in root points to the root directory where the script lives.
- Removing dead variables is part of refactoring — don't carry tech debt forward.

**Task conclusion**:
Students complete Phase 1 modularization and see that refactoring includes cleaning up obsolete inputs, not only moving files around.

---

### Task 7: Apply and Verify

All 26 resources are now in modules and every `terraform plan` so far has been clean — but nothing has been applied yet. This task runs `terraform apply` and proves the application still works end-to-end: zero resources recreated, zero downtime, same running website. This is the payoff moment that validates every decision made in Tasks 1–6.

**What students do**:
1. `terraform apply` — approve the plan (should be moves only).
2. Open the ALB DNS name in a browser — Space Invaders should load.
3. `terraform plan` — should show `No changes. Your infrastructure matches the configuration.`

**Validation**:
```bash
# Confirm app works
curl -s -o /dev/null -w "%{http_code}" http://<ALB_DNS_NAME>/
# Expected: 200

# Confirm clean state
terraform plan
# Expected: "No changes"
```

**Teaching points**:
- The entire refactor happened without a single resource being recreated.
- The app was available the entire time.
- This is the power of `moved` blocks + modules.

**Task conclusion**:
Students confirm that structural refactoring changed only the code organization, not the runtime behavior. The website was live throughout.

---

### Task 8: Mandatory Moved Block Cleanup (Phase 1 Closure)

With the apply confirmed and the plan clean, the `moved` blocks have served their purpose. This task removes them. Leaving stale `moved` blocks in the codebase creates confusion in future refactors and falsely signals that migration is still in progress. This cleanup is mandatory, not optional.

**What students do**:
1. Rename `moved.tf` to `moved.tf.bak`.
2. Run `terraform plan`.
3. If clean, delete `moved.tf.bak`.
4. If not clean, restore and fix missing mappings before retry.

**Validation**:
```bash
terraform plan
# Expected: "No changes" — even without moved.tf
```

**Teaching points**:
- `moved` blocks are only needed for the migration. Once the state file reflects the new addresses, they're inert.
- This cleanup is **mandatory**, not optional. Leaving stale `moved` blocks adds clutter and can cause confusion in future refactors.
- Students should understand the lifecycle: add → apply → verify → remove.

**Task conclusion**:
Students learn lifecycle ownership of migration metadata and internalize the discipline of removing scaffolding once it has served its purpose.

---

## 5. Phase 2 — Optimize to Show Module Power

**Goal**: Demonstrate reusability and DRY patterns. This phase **does** change the module structure, requiring new moved blocks for the internal reorganization. As with Phase 1, moved blocks are added in-task, not deferred.

---

### Task 9: Split Networking into VPC + Generic Subnets Module (+ Moved Blocks)

Phase 2 begins with the biggest structural change in the lab: splitting one module into three. Students decompose the monolithic networking module into a standalone VPC module and a generic subnets module called twice (public and private). This requires converting private subnets from `count` to `for_each` — a real-world migration pattern with its own moved blocks. Because three other module calls referenced `module.networking.*`, all of them must be updated to point to the new module outputs.

**What students do**:

1. **Create `modules/vpc/main.tf`** — move these resources from `modules/networking/main.tf`:
   | # | Resource | Source |
   |---|---|---|
   | 1 | `aws_vpc.custom-vpc` | `modules/networking/main.tf` |
   | 2 | `aws_internet_gateway.igw` | `modules/networking/main.tf` |
   | 3 | `aws_nat_gateway.ngw` | `modules/networking/main.tf` |

2. **Create `modules/vpc/variables.tf`**:
   | Variable | Type |
   |---|---|
   | `vpc_cidr` | `string` |
   | `vpc_name` | `string` |

3. **Create `modules/vpc/output.tf`**:
   | Output | Value |
   |---|---|
   | `vpc_id` | `aws_vpc.custom-vpc.id` |
   | `igw_id` | `aws_internet_gateway.igw.id` |
   | `ngw_id` | `aws_nat_gateway.ngw.id` |

4. **Create `modules/subnets/main.tf`** — a **generic** module (called twice), all using `for_each`:
   | # | Resource | Key |
   |---|---|---|
   | 1 | `aws_subnet.subnets` | `for_each = var.subnets` |
   | 2 | `aws_route_table.rt` | (single) |
   | 3 | `aws_route_table_association.assoc` | `for_each = aws_subnet.subnets` |

5. **Create `modules/subnets/variables.tf`**:
   | Variable | Type | Description |
   |---|---|---|
   | `vpc_id` | `string` | VPC ID |
   | `vpc_name` | `string` | VPC name (for tags) |
   | `subnets` | `map(string)` | Map of `{ az => cidr }` |
   | `map_public_ip` | `bool` | Whether subnets get public IPs |
   | `route_table_name` | `string` (default `null`) | Optional RT name tag |
   | `route_target_type` | `string` | `"igw"` or `"nat"` |
   | `route_target_id` | `string` | Gateway ID for the route |
   | `subnet_name_prefix` | `string` | Prefix for subnet name tags |
   | `subnet_name_by_az` | `map(string)` (default `{}`) | Optional per-AZ name overrides |

6. **Create `modules/subnets/output.tf`**:
   | Output | Value |
   |---|---|
   | `subnet_ids` | `values(aws_subnet.subnets)[*].id` |
   | `subnet_ids_by_az` | `{ for k, v in aws_subnet.subnets : k => v.id }` |
   | `route_table_id` | `aws_route_table.rt.id` |

7. **Move `data` and `locals` blocks** from `modules/networking/main.tf` back to root `main.tf`. Add the `private_subnets` local alongside the existing `public_subnets` local:
   ```hcl
   data "aws_availability_zones" "available" {
     state = "available"
   }

   locals {
     public_subnets = {
       for i, az in data.aws_availability_zones.available.names :
       az => cidrsubnet(var.vpc_cidr, 4, i)
     }

     private_subnets = {
       for i, az in data.aws_availability_zones.available.names :
       az => cidrsubnet(var.vpc_cidr, 4, i + 10)
     }
   }
   ```

8. **Replace `module "networking"` call** with three new module calls:
   ```hcl
   module "vpc" {
     source   = "./modules/vpc"
     vpc_cidr = var.vpc_cidr
     vpc_name = var.vpc_name
   }

   module "public_subnets" {
     source             = "./modules/subnets"
     vpc_id             = module.vpc.vpc_id
     vpc_name           = var.vpc_name
     subnets            = local.public_subnets
     map_public_ip      = true
     route_table_name   = var.route_table_name
     route_target_type  = "igw"
     route_target_id    = module.vpc.igw_id
     subnet_name_prefix = "public"
   }

   module "private_subnets" {
     source             = "./modules/subnets"
     vpc_id             = module.vpc.vpc_id
     vpc_name           = var.vpc_name
     subnets            = local.private_subnets
     map_public_ip      = false
     route_table_name   = null
     route_target_type  = "nat"
     route_target_id    = module.vpc.ngw_id
     subnet_name_prefix = "private"
   }
   ```

9. **Update downstream module calls** — all `module.networking.*` references change:
   | Module Call | Old Reference | New Reference |
   |---|---|---|
   | `module "security_groups"` | `module.networking.vpc_id` | `module.vpc.vpc_id` |
   | `module "load_balancer"` | `module.networking.vpc_id` | `module.vpc.vpc_id` |
   | `module "load_balancer"` | `module.networking.public_subnet_ids` | `module.public_subnets.subnet_ids` |
   | `module "autoscaling_group"` | `module.networking.private_subnet_ids` | `module.private_subnets.subnet_ids` |

10. **Delete `modules/networking/` directory**.

11. **Add moved blocks** to `moved.tf` (13 entries, including `count` → `for_each` per-AZ mappings):
    | From | To |
    |---|---|
    | `module.networking.aws_vpc.custom-vpc` | `module.vpc.aws_vpc.custom-vpc` |
    | `module.networking.aws_internet_gateway.igw` | `module.vpc.aws_internet_gateway.igw` |
    | `module.networking.aws_nat_gateway.ngw` | `module.vpc.aws_nat_gateway.ngw` |
    | `module.networking.aws_subnet.public_subnets` | `module.public_subnets.aws_subnet.subnets` |
    | `module.networking.aws_route_table.public_rt` | `module.public_subnets.aws_route_table.rt` |
    | `module.networking.aws_route_table_association.public_assoc` | `module.public_subnets.aws_route_table_association.assoc` |
    | `module.networking.aws_subnet.private_subnets[0]` | `module.private_subnets.aws_subnet.subnets["us-east-2a"]` |
    | `module.networking.aws_subnet.private_subnets[1]` | `module.private_subnets.aws_subnet.subnets["us-east-2b"]` |
    | `module.networking.aws_subnet.private_subnets[2]` | `module.private_subnets.aws_subnet.subnets["us-east-2c"]` |
    | `module.networking.aws_route_table.private_rt` | `module.private_subnets.aws_route_table.rt` |
    | `module.networking.aws_route_table_association.private_assoc[0]` | `module.private_subnets.aws_route_table_association.assoc["us-east-2a"]` |
    | `module.networking.aws_route_table_association.private_assoc[1]` | `module.private_subnets.aws_route_table_association.assoc["us-east-2b"]` |
    | `module.networking.aws_route_table_association.private_assoc[2]` | `module.private_subnets.aws_route_table_association.assoc["us-east-2c"]` |

12. **Run `terraform plan`**.

**Plan gate**:
```bash
terraform plan
# Expected: 0 to add, 0 to change, 0 to destroy
```

**Teaching points**:
- One module, two calls — this is the power of reusable modules.
- `for_each` everywhere gives stable, readable state addresses.
- The `count → for_each` migration is a real-world pattern students should know.
- **Consumer rewiring**: When replacing a module, every reference to the old module's outputs must be updated in all downstream module calls — the same pattern as Phase 1's flat file rewiring.
- Data sources and locals are implementation details. Moving them back to root when splitting a module is a normal part of refactoring module boundaries.

**Task conclusion**:
Students see how to optimize module granularity for reuse without breaking live infrastructure. The same `subnets` module serves both public and private use cases.

---

### Task 10: Make Security Groups Generic (+ Moved Blocks)

Students apply the same "one module, multiple calls" pattern to security groups. The Phase 1 combined `security-groups` module is replaced by a generic `security-group` (singular) module that accepts configurable rule maps via complex variable types (`map(object({...}))`) and creates one SG per call. This is the most complex set of moved blocks in the lab — rule resources change from individually-named addresses to `for_each`-keyed addresses, and the two downstream module calls must switch from the old combined module's outputs to the new per-SG module outputs.

**What students do**:

1. **Create `modules/security-group/main.tf`** (singular) — a generic module that creates **one** SG with configurable rules:
   | # | Resource | Key |
   |---|---|---|
   | 1 | `aws_security_group.this` | (single) |
   | 2 | `aws_vpc_security_group_ingress_rule.ingress` | `for_each = var.ingress_rules` |
   | 3 | `aws_vpc_security_group_egress_rule.egress` | `for_each = var.egress_rules` |

2. **Create `modules/security-group/variables.tf`**:
   | Variable | Type | Description |
   |---|---|---|
   | `name` | `string` | Security group name |
   | `description` | `string` | Security group description |
   | `vpc_id` | `string` | VPC ID |
   | `ingress_rules` | `map(object({ from_port, to_port, ip_protocol, cidr_ipv4?, referenced_security_group_id? }))` | Ingress rule map |
   | `egress_rules` | `map(object({ ip_protocol, cidr_ipv4? }))` | Egress rule map |

3. **Create `modules/security-group/output.tf`**:
   | Output | Value |
   |---|---|
   | `sg_id` | `aws_security_group.this.id` |

4. **Replace `module "security_groups"` call** with two new module calls:
   ```hcl
   module "alb_security_group" {
     source      = "./modules/security-group"
     name        = "${var.account}-alb-sg"
     description = "Allow HTTP from internet to ALB"
     vpc_id      = module.vpc.vpc_id
     ingress_rules = {
       alb_http_in = { from_port = 80, to_port = 80, ip_protocol = "tcp", cidr_ipv4 = "0.0.0.0/0" }
     }
     egress_rules = {
       alb_all_out = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
     }
   }

   module "app_security_group" {
     source      = "./modules/security-group"
     name        = var.security_group_name
     description = "Enable HTTP and SSH Access"
     vpc_id      = module.vpc.vpc_id
     ingress_rules = {
       allow-http-ipv4 = { from_port = 80, to_port = 80, ip_protocol = "tcp", referenced_security_group_id = module.alb_security_group.sg_id }
       allow-ssh-ipv4  = { from_port = 22, to_port = 22, ip_protocol = "tcp", cidr_ipv4 = "0.0.0.0/0" }
     }
     egress_rules = {
       allow-all-outbound = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
     }
   }
   ```

5. **Update downstream module calls** — SG output name changes from combined to per-SG:
   | Module Call | Old Reference | New Reference |
   |---|---|---|
   | `module "load_balancer"` | `module.security_groups.alb_sg_id` | `module.alb_security_group.sg_id` |
   | `module "autoscaling_group"` | `module.security_groups.app_sg_id` | `module.app_security_group.sg_id` |

6. **Delete `modules/security-groups/` directory** (plural, replaced by singular `modules/security-group/`).

7. **Add moved blocks** to `moved.tf` (7 entries — named → `for_each`-keyed):
   | From | To |
   |---|---|
   | `module.security_groups.aws_security_group.alb_sg` | `module.alb_security_group.aws_security_group.this` |
   | `module.security_groups.aws_vpc_security_group_ingress_rule.alb_http_in` | `module.alb_security_group.aws_vpc_security_group_ingress_rule.ingress["alb_http_in"]` |
   | `module.security_groups.aws_vpc_security_group_egress_rule.alb_all_out` | `module.alb_security_group.aws_vpc_security_group_egress_rule.egress["alb_all_out"]` |
   | `module.security_groups.aws_security_group.allow-http-ssh` | `module.app_security_group.aws_security_group.this` |
   | `module.security_groups.aws_vpc_security_group_ingress_rule.allow-http-ipv4` | `module.app_security_group.aws_vpc_security_group_ingress_rule.ingress["allow-http-ipv4"]` |
   | `module.security_groups.aws_vpc_security_group_ingress_rule.allow-ssh-ipv4` | `module.app_security_group.aws_vpc_security_group_ingress_rule.ingress["allow-ssh-ipv4"]` |
   | `module.security_groups.aws_vpc_security_group_egress_rule.allow-all-outbound` | `module.app_security_group.aws_vpc_security_group_egress_rule.egress["allow-all-outbound"]` |

   > **Key insight**: Using the original rule names as map keys (e.g., `alb_http_in`, `allow-http-ipv4`) makes the moved blocks straightforward — the resource name becomes the `for_each` key.

8. **Run `terraform plan`**.

**Plan gate**:
```bash
terraform plan
# Expected: 0 to add, 0 to change, 0 to destroy
```

**Teaching points**:
- One generic module eliminates repeated boilerplate.
- `for_each` over rule maps gives stable, named state addresses.
- Order of module calls matters: ALB SG must be created before app SG (which references it).
- Using map keys that match the original resource names simplifies moved blocks.
- **Consumer rewiring**: `load_balancer` and `autoscaling_group` module calls must update their SG input references from the old combined module's outputs to the new individual module outputs.

**Task conclusion**:
Students finish Phase 2 with the most advanced pattern: generic, reusable modules with complex variable types and `for_each` iteration. The entire infrastructure has been modernized without a single resource being recreated.

---

## 6. Phase 3 — Optional Challenge: Replace Local SG Module with Terraform Registry Module

**Goal**: For advanced students who want additional practice. This optional phase replaces the custom `security-group` module built in Phase 2 with the community-maintained `terraform-aws-modules/security-group/aws` from the Terraform Registry. This teaches build-vs-buy decision making, version constraints, and how to work with third-party module interfaces.

> **Note**: This phase is entirely optional. Students who complete Phases 1 and 2 have already achieved the core learning objectives. Phase 3 is a challenge extension.

### Why a Separate Phase?

Mixing registry module exploration into the same task as the SG refactor would overload students with two unrelated concepts at once (generic module design *and* registry consumption). Separating them lets each phase stand on its own learning objective:
- Phase 2: Design reusable modules.
- Phase 3: Evaluate and consume community modules.

### What Changes from Phase 2?

Only the security-group approach changes. Everything else (VPC, subnets, S3, LB, ASG) remains identical to Phase 2. The `phase3-registry/` directory in the repository contains **only the files that differ from Phase 2**.

### Task 11 (Challenge): Replace Custom SG Module with Registry Module

Students replace the custom `security-group` module with the community-maintained `terraform-aws-modules/security-group/aws` from the Terraform Registry. This is a fundamentally different kind of refactor: the registry module has its own internal resource naming and its own output names (`security_group_id` instead of `sg_id`), so students must write new moved blocks *and* update every downstream reference to match the new output contract.

**What students do**:

1. **Replace both `module "alb_security_group"` and `module "app_security_group"` calls** with registry module source:
   ```hcl
   module "alb_security_group" {
     source  = "terraform-aws-modules/security-group/aws"
     version = "~> 5.0"

     name        = "${var.account}-alb-sg"
     description = "Allow HTTP from internet to ALB"
     vpc_id      = module.vpc.vpc_id

     ingress_with_cidr_blocks = [
       { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = "0.0.0.0/0" }
     ]
     egress_with_cidr_blocks = [
       { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = "0.0.0.0/0" }
     ]
   }

   module "app_security_group" {
     source  = "terraform-aws-modules/security-group/aws"
     version = "~> 5.0"

     name        = var.security_group_name
     description = "Enable HTTP and SSH Access"
     vpc_id      = module.vpc.vpc_id

     ingress_with_source_security_group_id = [
       { from_port = 80, to_port = 80, protocol = "tcp", source_security_group_id = module.alb_security_group.security_group_id }
     ]
     ingress_with_cidr_blocks = [
       { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = "0.0.0.0/0" }
     ]
     egress_with_cidr_blocks = [
       { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = "0.0.0.0/0" }
     ]
   }
   ```

2. **Update downstream references** — registry module outputs `security_group_id` (not `sg_id`):
   | Module Call | Old Reference | New Reference |
   |---|---|---|
   | `module "app_security_group"` call | `module.alb_security_group.sg_id` | `module.alb_security_group.security_group_id` |
   | `module "load_balancer"` | `module.alb_security_group.sg_id` | `module.alb_security_group.security_group_id` |
   | `module "autoscaling_group"` | `module.app_security_group.sg_id` | `module.app_security_group.security_group_id` |

3. **Delete `modules/security-group/` directory** (no longer needed).

4. **Add moved blocks** to `moved.tf` (2 entries — **SG base resources only**):
   | From | To |
   |---|---|
   | `module.alb_security_group.aws_security_group.this` | `module.alb_security_group.aws_security_group.this[0]` |
   | `module.app_security_group.aws_security_group.this` | `module.app_security_group.aws_security_group.this[0]` |

   > **Critical limitation**: The registry module uses `aws_security_group_rule` (classic) while Phase 2 used `aws_vpc_security_group_*_rule` (VPC-native). These are **different resource types** — rules CANNOT be moved. Terraform will destroy the old VPC-native rules and create new classic rules. This is expected and unavoidable.

5. **Run `terraform init`** (downloads registry module), then **`terraform plan`**.

   > **Expected plan**: The SG resources show "has moved to" annotations. The old VPC-native rules are destroyed and new classic rules are created. This is NOT a zero-change plan — the rule type difference makes that impossible.

**Discussion points** (compare local vs registry):
- Input surface area: registry modules often have dozens of variables; local modules have exactly what you need.
- Output ergonomics: registry modules export many outputs; local modules export only what downstream consumers need.
- Customization limits: registry modules may not support every edge case.
- Upgrade/version management: registry modules can be pinned and upgraded independently.
- When to break modules into their own repos vs monorepo.
- Terraform Registry (public and private).

**Task conclusion**:
Students gain practical experience consuming community modules and learn to evaluate the trade-offs between building custom modules (full control, minimal interface) and consuming registry modules (less code to maintain, broader feature set, version management overhead).

---

## 7. Complete Moved Blocks Reference

### Phase 1: Flat → Module (26 blocks)

```hcl
# ======================
# moved.tf
# ======================

# --- S3 Bucket (5) ---
moved {
  from = aws_s3_bucket.bucket
  to   = module.s3_bucket.aws_s3_bucket.bucket
}
moved {
  from = aws_s3_bucket_ownership_controls.this
  to   = module.s3_bucket.aws_s3_bucket_ownership_controls.this
}
moved {
  from = aws_s3_bucket_public_access_block.this
  to   = module.s3_bucket.aws_s3_bucket_public_access_block.this
}
moved {
  from = aws_s3_bucket_versioning.versioning
  to   = module.s3_bucket.aws_s3_bucket_versioning.versioning
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.encryption
  to   = module.s3_bucket.aws_s3_bucket_server_side_encryption_configuration.encryption
}

# --- Networking (9) ---
moved {
  from = aws_vpc.custom-vpc
  to   = module.networking.aws_vpc.custom-vpc
}
moved {
  from = aws_subnet.public_subnets
  to   = module.networking.aws_subnet.public_subnets
}
moved {
  from = aws_internet_gateway.igw
  to   = module.networking.aws_internet_gateway.igw
}
moved {
  from = aws_nat_gateway.ngw
  to   = module.networking.aws_nat_gateway.ngw
}
moved {
  from = aws_route_table.public_rt
  to   = module.networking.aws_route_table.public_rt
}
moved {
  from = aws_route_table_association.public_assoc
  to   = module.networking.aws_route_table_association.public_assoc
}
moved {
  from = aws_subnet.private_subnets
  to   = module.networking.aws_subnet.private_subnets
}
moved {
  from = aws_route_table.private_rt
  to   = module.networking.aws_route_table.private_rt
}
moved {
  from = aws_route_table_association.private_assoc
  to   = module.networking.aws_route_table_association.private_assoc
}

# --- Security Groups (7) ---
moved {
  from = aws_security_group.allow-http-ssh
  to   = module.security_groups.aws_security_group.allow-http-ssh
}
moved {
  from = aws_vpc_security_group_ingress_rule.allow-http-ipv4
  to   = module.security_groups.aws_vpc_security_group_ingress_rule.allow-http-ipv4
}
moved {
  from = aws_vpc_security_group_ingress_rule.allow-ssh-ipv4
  to   = module.security_groups.aws_vpc_security_group_ingress_rule.allow-ssh-ipv4
}
moved {
  from = aws_vpc_security_group_egress_rule.allow-all-outbound
  to   = module.security_groups.aws_vpc_security_group_egress_rule.allow-all-outbound
}
moved {
  from = aws_security_group.alb_sg
  to   = module.security_groups.aws_security_group.alb_sg
}
moved {
  from = aws_vpc_security_group_ingress_rule.alb_http_in
  to   = module.security_groups.aws_vpc_security_group_ingress_rule.alb_http_in
}
moved {
  from = aws_vpc_security_group_egress_rule.alb_all_out
  to   = module.security_groups.aws_vpc_security_group_egress_rule.alb_all_out
}

# --- Load Balancer (3) ---
moved {
  from = aws_lb.web_alb
  to   = module.load_balancer.aws_lb.web_alb
}
moved {
  from = aws_lb_target_group.web_tg
  to   = module.load_balancer.aws_lb_target_group.web_tg
}
moved {
  from = aws_lb_listener.web_listener
  to   = module.load_balancer.aws_lb_listener.web_listener
}

# --- Autoscaling Group (2) ---
moved {
  from = aws_launch_template.web_template
  to   = module.autoscaling_group.aws_launch_template.web_template
}
moved {
  from = aws_autoscaling_group.web_asg
  to   = module.autoscaling_group.aws_autoscaling_group.web_asg
}
```

---

## 8. Variable & Output Contract Reference

### Root Variables (after Task 6 cleanup)

| Variable | Type | Consumed By |
|---|---|---|
| `region` | `string` | `provider`, `autoscaling_group` (AMI lookup) |
| `vpc_name` | `string` | `networking` |
| `vpc_cidr` | `string` | `networking` |
| `route_table_name` | `string` | `networking` |
| `security_group_name` | `string` | `security_groups` |
| `account` | `string` | `security_groups`, `load_balancer`, `autoscaling_group` |
| `image_id` | `map(string)` | `autoscaling_group` (resolved at root: `var.image_id[var.region]`) |
| `instance_type` | `string` | `autoscaling_group` |
| `instance_count_min` | `number` | `autoscaling_group` |
| `instance_count_max` | `number` | `autoscaling_group` |

**Removed in Task 6** (obsolete — no module consumed them):
| Variable | Reason |
|---|---|
| `public_subnet_a_name` | Vestigial from Lab 02 single-subnet design; superseded by dynamic subnets in Lab 04 |
| `public_subnet_a_cidr` | Same as above |

### Cross-Module Data Flow

```
                         ┌──────────────┐
                    ┌───►│  s3_bucket   │──► bucket_name (output)
                    │    └──────────────┘
                    │
                    │    ┌──────────────┐
                    ├───►│  networking  │──► vpc_id
                    │    │              │──► public_subnet_ids
                    │    │              │──► private_subnet_ids
                    │    └──────┬───────┘
                    │           │
  root variables ───┤           ▼
                    │    ┌──────────────────┐
                    ├───►│ security_groups  │──► app_sg_id
                    │    │  (needs vpc_id)  │──► alb_sg_id
                    │    └──────┬───────────┘
                    │           │
                    │           ▼
                    │    ┌──────────────────┐
                    ├───►│  load_balancer   │──► alb_dns_name (root re-exposes as load_balancer_dns)
                    │    │  (needs vpc_id,  │──► target_group_arn
                    │    │   alb_sg_id,     │
                    │    │   public_subnets)│
                    │    └──────┬───────────┘
                    │           │
                    │           ▼
                    │    ┌──────────────────┐
                    └───►│autoscaling_group │
                         │  (needs app_sg,  │
                         │   private_subs,  │
                         │   target_grp_arn)│
                         └──────────────────┘
```

---

## 9. Validation Checklist

Use after each task to confirm correctness.

### Per-Task Validation (every task)
```bash
terraform plan
# Expected: moved resources show "has moved to" annotations
# Expected: 0 to add, 0 to change, 0 to destroy
```

### State Migration Audit (Task 6)
```bash
terraform plan
# Expected output must contain ALL of:
#   - "0 to add"
#   - "0 to change"
#   - "0 to destroy"
#   - Multiple "has moved to" lines covering all 26 resources
```

### Functional Validation (Task 7)
```bash
# Apply
terraform apply

# Test ALB (replace with actual DNS)
curl -s -o /dev/null -w "%{http_code}" http://$(terraform output -raw load_balancer_dns)/
# Expected: 200

# Confirm idempotent
terraform plan
# Expected: "No changes. Your infrastructure matches the configuration."
```

### Post-Cleanup Validation (Task 8)
```bash
# After removing moved.tf
terraform plan
# Expected: "No changes" — moved blocks are inert after convergence
```

### Automated Validation Script
The `validate_progressive.ps1` script in the `aws/` folder can be extended to validate the modules structure. To validate the modules root independently:
```powershell
cd aws/website-with-modules
terraform init -backend=false
terraform validate
```

The `run_phase_deploy_local.ps1` script performs full deploy testing with local backend, auto-cleanup, and unique naming. It never uses `user01`.

---

## Common Failure Patterns to Watch

1. **Deferring moved blocks until the end** — catches errors too late, harder to isolate which task went wrong.
2. **Switching backend behavior mid-lab** — breaks continuity, may lose state.
3. **Renaming tags or names accidentally during module extraction** — causes drift (tag changes = plan changes).
4. **Removing variables before references are fully rewired** — terraform validate catches this, but plan is better.
5. **Leaving moved blocks in place after convergence** — creates confusion in future refactors.
6. **Carrying obsolete variables forward** — tech debt accumulates; remove dead inputs during refactor.
7. **Forgetting to rewire consumer references** — when extracting resources into a module, remaining flat files (Phase 1) or module calls (Phase 2/3) that referenced those resources must be updated to use module outputs. Missing this causes “reference to undeclared resource” errors.

---

## Appendix: Key Terraform Concepts Covered

| Concept | Where Introduced |
|---|---|
| Module basics (source, variables, outputs) | Phase 1, Tasks 2–6 |
| Cross-module references | Phase 1, Tasks 4–6 |
| Consumer rewiring during module extraction | Phase 1, Tasks 3–6; Phase 2, Tasks 9–10; Phase 3, Task 11 |
| `moved` blocks for safe refactoring | Phase 1, Tasks 2–6 (in-task, not deferred) |
| `path.module` vs `path.root` | Phase 1, Task 6 |
| Obsolete variable cleanup | Phase 1, Task 6 |
| Module output ownership (ALB DNS) | Phase 1, Task 5 |
| Mandatory moved cleanup | Phase 1, Task 8 |
| Module reusability (same module, multiple calls) | Phase 2, Tasks 9–10 |
| `for_each` vs `count` trade-offs | Phase 2, Task 9 |
| `count` → `for_each` migration | Phase 2, Task 9 |
| Dynamic/generic modules with complex variable types | Phase 2, Task 10 |
| Terraform Registry modules — build vs buy | Phase 3, Task 11 |
| Version constraints in module `source` blocks | Phase 3, Task 11 |

---

## Repository Alignment Notes

The current repository implementation aligns with this plan:

1. **Delta directory pattern**: Each phase directory contains only files that changed from the previous phase, not a full copy. `phase1-modularized` is the complete Phase 1 end state. `phase2-optimized` contains only the root files and modules that differ from Phase 1. `phase3-registry` contains only the files that differ from Phase 2.
2. `phase1-modularized` and `phase2-optimized` removed obsolete root inputs:
   - `public_subnet_a_name`
   - `public_subnet_a_cidr`
3. Temp validation runner (`run_phase_deploy_local.ps1`) performs pre-run and post-run cleanup.
4. Runner uses unique naming to avoid collisions and does not rely on `user01`.