# Lab 06 - Refactor to Modules (Revised Plan)

This lab refactors the existing flat Terraform configuration into modules without rebuilding infrastructure. Students stay in the same working folder and same backend/state they already use from prior labs. The core pattern is iterative: make a focused refactor, add the matching `moved` blocks immediately, and run `terraform plan` to verify no unintended add/change/destroy before moving on.

## Assumptions
- Students start from the end of the prior lab in the same folder.
- Backend/state are already configured and in use.
- Validation command for this lab is `terraform plan` (not `terraform init -backend=false` / `terraform validate`).
- Never use `user01` for test execution in instructor automation.

## Task 1 - Preflight and Baseline Cleanup

Before refactoring, students establish a clean baseline and ensure no stale migration metadata remains.

Steps:
1. Confirm workspace is the same folder used in the previous lab.
2. If old `moved` blocks exist from prior experiments, move them out of active config (for example to `moved.tf.bak`).
3. Run `terraform plan`.
4. If plan is not clean, resolve drift before continuing.

Validation:
- `terraform plan` shows no unexpected changes.

Task Summary:
Students verify they are starting from a stable baseline and understand that refactoring should preserve infrastructure, not recreate it.

## Task 2 - Create S3 Module and Move S3 Addresses

Students modularize the S3 state bucket resources first, then immediately map old addresses with `moved` blocks.

Steps:
1. Add `modules/s3-bucket`.
2. Move existing S3 resource blocks into the module.
3. Wire root module call and root outputs.
4. Add S3-related `moved` blocks in `moved.tf`.
5. Run `terraform plan`.

Validation:
- `terraform plan` shows S3 addresses moved and no recreate.

Task Summary:
Students learn the core migration loop: refactor, map state addresses, verify plan.

## Task 3 - Create Networking Module and Move VPC/Subnet/Route Resources

Students modularize VPC, public/private subnets, route tables, and associations while preserving current behavior.

Steps:
1. Add `modules/networking`.
2. Move VPC, subnet, NAT, IGW, route table, and association resources.
3. Keep current logic intact (`for_each` for public subnets and `count` for private subnets in Phase 1).
4. Add networking-related `moved` blocks.
5. Run `terraform plan`.

Validation:
- `terraform plan` shows moved resources only, no recreate.

Task Summary:
Students practice preserving behavior during structural changes and understand how iteration strategy affects addresses.

## Task 4 - Create Security Groups Module and Move SG Resources

Students modularize app and ALB security groups and all associated ingress/egress rule resources.

Steps:
1. Add `modules/security-groups`.
2. Move both SG resources and all rule resources.
3. Wire module inputs/outputs in root.
4. Add SG-related `moved` blocks.
5. Run `terraform plan`.

Validation:
- `terraform plan` shows moved SG resources with no destructive actions.

Task Summary:
Students see how tightly related resources are grouped as a single module boundary to reduce cross-module coupling.

## Task 5 - Create Load Balancer Module and Move LB Resources

Students modularize ALB, target group, and listener, then map addresses.

Steps:
1. Add `modules/load-balancer`.
2. Move ALB, TG, and listener resources.
3. Wire module outputs for `alb_dns_name` and `target_group_arn`.
4. Keep `load_balancer_dns` root output sourced from the load balancer module.
5. Add LB-related `moved` blocks.
6. Run `terraform plan`.

Validation:
- `terraform plan` remains clean except moved notices.

Task Summary:
Students learn clean module contracts: the LB module owns ALB DNS output, and downstream modules consume only required outputs.

## Task 6 - Create Autoscaling Module, Move ASG Resources, and Remove Legacy Root Inputs

Students modularize launch template + ASG and remove long-obsolete root variables.

Steps:
1. Add `modules/autoscaling-group`.
2. Move launch template and ASG resources.
3. Wire root/module inputs and outputs.
4. Add ASG-related `moved` blocks.
5. Remove deprecated root vars from modularized configs:
   - `public_subnet_a_name`
   - `public_subnet_a_cidr`
6. Remove matching entries from modularized `terraform.tfvars`.
7. Run `terraform plan`.

Validation:
- `terraform plan` shows no unintended changes.

Task Summary:
Students complete modularization and reduce technical debt by deleting unused inputs instead of carrying dead configuration.

## Task 7 - Moved Block Audit and Final Phase 1 Plan Check

Students verify that every migrated resource has an explicit move mapping.

Steps:
1. Review all resources moved so far.
2. Confirm `moved.tf` includes every old-to-new address mapping.
3. Run `terraform plan`.

Validation:
- `terraform plan` shows no create/destroy due to missing address mapping.

Task Summary:
Students reinforce state-safety discipline and learn how missing `moved` entries surface in plan output.

## Task 8 - Apply and Functional Verification

Students apply the finished Phase 1 refactor and verify app behavior.

Steps:
1. Run `terraform apply`.
2. Retrieve ALB DNS output.
3. Confirm app responds from ALB endpoint.
4. Run `terraform plan` to confirm idempotency.

Validation:
- App responds successfully.
- Final plan is clean.

Task Summary:
Students prove that refactoring changed structure, not behavior.

## Task 9 - Mandatory Moved Block Cleanup

Students finish Phase 1 by removing migration scaffolding only after state has fully converged.

Steps:
1. Rename `moved.tf` to `moved.tf.bak`.
2. Run `terraform plan`.
3. If still clean, delete `moved.tf.bak`.

Validation:
- `terraform plan` remains clean with no moved file.

Task Summary:
Students understand `moved` blocks are migration metadata, not permanent infrastructure logic.

## Task 10 - Phase 2 Optimization: Split Networking and Add Moves During Refactor

Students optimize module design for reuse and add moved mappings as part of the task (not deferred).

Steps:
1. Split networking into:
   - `modules/vpc`
   - `modules/subnets` (called for public and private)
2. Standardize subnet generation to reusable patterns.
3. Add moved blocks in this task for all address changes introduced here.
4. Run `terraform plan`.

Validation:
- `terraform plan` remains non-destructive.

Task Summary:
Students move from modularization to reusable module architecture while preserving live infrastructure.

## Task 11 - Phase 2 Optimization: SG Refactor and Registry Module Demonstration

Students complete Phase 2 with final SG refactor and incorporate Terraform Registry module usage as discussed in lecture.

Steps:
1. Refactor SG approach as designed for Phase 2.
2. Add any remaining moved blocks introduced by this refactor in the same task.
3. Run `terraform plan` and ensure no unintended recreate.
4. Registry demonstration:
   - Add an instructor-led example that consumes a Terraform Registry module (for example, `terraform-aws-modules/security-group/aws`) in a controlled variant/sandbox path.
   - Compare interface, outputs, and tradeoffs vs local custom module.

Validation:
- Main Phase 2 path stays clean.
- Registry example is understood and reproducible for discussion.

Task Summary:
Students finish with both advanced refactor mechanics and practical understanding of when to build local modules vs consume registry modules.

## Notes for Instructor Validation Workflow
- Preferred check after each task: `terraform plan`.
- Add `moved` blocks in the same task as the refactor.
- Do not defer all moved blocks to the end.
- Keep ALB DNS output owned by the load balancer module and exposed via root output.

## Current Repository Alignment
- `phase1-modularized` and `phase2-optimized` now remove deprecated root inputs:
  - `public_subnet_a_name`
  - `public_subnet_a_cidr`
- Temp-run script auto-cleans test resources and avoids `user01` naming collisions by generating unique run tags.