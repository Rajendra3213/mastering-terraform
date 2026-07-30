# Terraform Deep Dive

A hands-on, chapter-by-chapter guide to Terraform — from *what even is Infrastructure as Code* through advanced patterns like dynamic blocks, map transformations, and module composition, ending with the mistakes that quietly wreck production.

Every chapter is a standalone Markdown lesson with real, copy-pasteable HCL (mostly AWS) and an explanation of *why* the pattern exists, not just how to type it.

## Who this is for

- You've run `terraform apply` at least once and want to go deeper.
- You can write a basic resource block but freeze up at `for_each`, `dynamic`, or `for` expressions.
- You inherited a 3,000-line `main.tf` and want to know what "good" looks like.

Total beginners are welcome too — start at Chapter 1 and read straight through.

## Chapter index

### Part 1 — Foundations

| # | Chapter | What you'll learn |
|---|---------|-------------------|
| 01 | [What the Heck is Infrastructure as Code?](Introductiond-01.md) | The problems IaC solves, why Terraform won, and your first steps |
| 02 | [Variables and Locals](locals-and-variables-02.md) | Killing hard-coded values; string, number, list, and map types; when to reach for `locals` |
| 03 | [State and Providers](terraform-state-provider-03.md) | How state tracks reality, and multi-cloud provider configuration |
| 04 | [Resources and Data Sources](terraform-resources-data-sources-04.md) | Resources vs. data sources, wiring up a real EC2 instance, security group, and AMI lookup |

### Part 2 — Making Code Flexible

| # | Chapter | What you'll learn |
|---|---------|-------------------|
| 05 | [Count and For_Each](count-and-for-each-05.md) | Creating many resources from one block, `count.index`, and lists vs. maps |
| 06 | [If/Else Conditions](terraform-if-else-condition-06.md) | Ternaries, conditional attributes, replacing invalid values, conditional resource creation |
| 07 | [Dynamic Blocks](terraform-dynamic-block-07.md) | Generating repeated nested blocks (ingress rules, tags) instead of copy-pasting them |
| 08 | [Functions](terraform-functions-08.md) | The string, list, map, and math functions you'll actually reach for |

### Part 3 — Advanced Patterns

| # | Chapter | What you'll learn |
|---|---------|-------------------|
| 09 | [Modules](terraform-modules-09.md) | Composition over repetition, the module mindset, and advanced patterns |
| 10 | [Map Transformations](terraform-map-transformations-10.md) | `for` expressions over maps, with a real Lambda + S3-trigger example |
| 11 | [Workspaces](terraform-workspaces-11.md) | Managing dev/staging/prod, and where workspaces stop being the right tool |

### Part 4 — Production Readiness

| # | Chapter | What you'll learn |
|---|---------|-------------------|
| 12 | [Best Practices](terraform-best-practices-12.md) | File layout, variable design patterns, resource naming and tagging |
| 13 | [The 7 Deadly Sins of Terraform](deadly-sins-at-terraform-13.md) | The monster `main.tf`, copy-paste environment hell, and the rest — each with a fix |

## Suggested paths

- **New to Terraform:** 01 → 04, then continue in order.
- **Comfortable with the basics:** start at 05 and read through to 13.
- **Cleaning up an existing codebase:** 13 → 12 → 09, then 05 and 10 for the actual refactors.
- **Just need a reference:** 08 (functions) and 10 (map transformations) work fine standalone.

## Getting started

```bash
git clone <your-repo-url>
cd terraform-deep-dive
```

Then open [Chapter 01](Introductiond-01.md) and read on. To follow along with the examples you'll want:

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer
- An AWS account with credentials configured (`aws configure`) — most examples target AWS
- An editor with HCL syntax highlighting

## Feedback

Found something unclear, or spotted a mistake? Open an issue — corrections and questions are equally welcome.

---

**A word of caution:** these examples create real cloud resources that cost real money. Read the code first, always run `terraform plan` before `apply`, and `terraform destroy` when you're done experimenting. Never point an example at a production account.
