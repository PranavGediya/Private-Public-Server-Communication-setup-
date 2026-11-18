# My-VPC: Public and Private Web Server Communication on AWS (Terraform)

This project builds a two-tier network in **eu-north-1** with Terraform and shows how
public servers and a private server talk to each other.

- 1 VPC (`My-VPC`, `10.0.0.0/16`)
- 2 public subnets and 2 private subnets across 2 Availability Zones
- Internet Gateway (`MY-IGW`) and NAT Gateway (`MY-NAT`)
- 2 security groups (`Public Web`, `Private app`)
- 3 EC2 instances: `PublicS1`, `PublicS2` (public) and `PrivateS3` (private)

---

## 1. Architecture

```
                           Internet
                              |
                         [ MY-IGW ]
                              |
+--------------------- My-VPC 10.0.0.0/16 ----------------------+
|                                                               |
|  PUBLIC  (MAIN route table: 0.0.0.0/0 -> MY-IGW)              |
|  +--------------------+            +--------------------+     |
|  | public-1a          |            | public-1b          |     |
|  | 10.0.1.0/24        |            | 10.0.2.0/24        |     |
|  | PublicS1           | <--------> | PublicS2           |     |
|  | MY-NAT lives here  |            |                    |     |
|  +--------------------+            +--------------------+     |
|          |                                                    |
|          |  HTTP + ping over private IPs                      |
|          v                                                    |
|  PRIVATE (Private-RT: 0.0.0.0/0 -> MY-NAT)                    |
|  +--------------------+            +--------------------+     |
|  | private-1a         |            | private-1b         |     |
|  | 10.0.3.0/24        |            | 10.0.4.0/24        |     |
|  | (no server)        |            | PrivateS3          |     |
|  +--------------------+            +--------------------+     |
+---------------------------------------------------------------+
```

| Subnet | CIDR | AZ | Route table | Auto public IP |
|---|---|---|---|---|
| public-1a | 10.0.1.0/24 | eu-north-1a | MAIN (-> IGW) | Yes |
| public-1b | 10.0.2.0/24 | eu-north-1b | MAIN (-> IGW) | Yes |
| private-1a | 10.0.3.0/24 | eu-north-1a | Private-RT (-> NAT) | No |
| private-1b | 10.0.4.0/24 | eu-north-1b | Private-RT (-> NAT) | No |

---

## 2. How the servers communicate

| Traffic | Path | Allowed by |
|---|---|---|
| Internet -> PublicS1 / PublicS2 (HTTP 80, SSH 22) | Internet -> MY-IGW -> public subnet | `Public Web` inbound rules from `0.0.0.0/0` |
| PublicS1 <-> PublicS2 (ping, HTTP) | Local route inside the VPC | `Public Web` inbound ICMP rule that references itself |
| PublicS1 / PublicS2 -> PrivateS3 (HTTP, ping) | Local route inside the VPC | `Private app` inbound HTTP and ICMP rules that reference `Public Web` |
| PrivateS3 -> Internet (for example `yum install`) | Private-RT -> MY-NAT -> MY-IGW | `Private app` outbound allow-all rule |
| Internet -> PrivateS3 | Not possible | No public IP, no inbound route, no inbound rule |

Four ideas explain all of this:

1. **The local route.** Every route table in a VPC has an automatic route for `10.0.0.0/16`
   that points to `local`. Because of it, servers in different subnets (public or private)
   can reach each other by private IP without any gateway.
2. **Security groups decide who is allowed.** Routing only provides the path. A security
   group still has to allow the traffic. `Private app` accepts HTTP and ping only from
   members of `Public Web`, so the internet and anything outside that group can't reach it.
3. **Referencing a security group instead of an IP range.** `Private app` uses
   `Public Web` as the *source*. Any instance in `Public Web` is allowed, even if its IP
   changes. This only matches **private IPs**, so always test with private IPs.
4. **NAT is one-way.** `PrivateS3` has no public IP. Its outbound traffic goes to `MY-NAT`
   (in `public-1a`), which uses an Elastic IP to reach the internet. Replies come back, but
   nobody on the internet can start a connection to `PrivateS3`.

Security groups are **stateful**. If a request is allowed in, the reply is allowed out
automatically, so you only write the inbound rule for the request.

---

## 3. Project files

| File | What it does |
|---|---|
| `providers.tf` | Terraform and provider versions, AWS region |
| `variables.tf` | Region, CIDRs, subnets, AMI, instance type, user data path |
| `network.tf` | VPC, IGW, subnets, MAIN and Private route tables, NAT gateway + Elastic IP |
| `security.tf` | `Public Web` and `Private app` security groups (HTTP, SSH, ICMP rules) |
| `ec2.tf` | 3 key pairs (saved to `keys/`) and the 3 instances |
| `outputs.tf` | IPs, subnet IDs and SSH commands |
| `userdata.sh` | Boot script: installs Apache and writes an index page with the subnet ID |
| `.gitignore` | Keeps keys and state files out of Git |

---

## 4. Prerequisites

- Terraform 1.5 or newer (`terraform -version`)
- AWS CLI configured with credentials that can create VPC, EC2 and Elastic IP resources
- An SSH client (Linux or macOS terminal, or Git Bash / WSL on Windows)

---

## 5. Setup step by step

### Step 1: Check your AWS credentials

```bash
aws configure                 # only if you haven't set credentials yet
aws sts get-caller-identity   # should print your account ID
```

### Step 2: Go to the project folder

```bash
cd my-vpc-terraform
```

### Step 3: Initialise Terraform

Downloads the AWS, TLS and Local providers.

```bash
terraform init
```

### Step 4: Format and validate

```bash
terraform fmt
terraform validate
```

### Step 5: Review the plan

```bash
terraform plan
```

Check that it creates the VPC, 4 subnets, IGW, NAT + Elastic IP, 2 route tables,
2 security groups with their rules, 3 key pairs and 3 instances.

### Step 6: Apply

```bash
terraform apply
```

Type `yes` when asked. The NAT gateway takes about 1 to 2 minutes, so the full apply takes a few minutes.

### Step 7: Read the outputs

```bash
terraform output
```

You will see the public IPs of `PublicS1` and `PublicS2`, the private IPs of all 3 servers,
and ready-made SSH commands. Wait 2 to 3 minutes after the apply so the user data script
can finish installing Apache on every server.

---

## 6. Test the communication

### Test A: Public servers from the internet

Open these in your browser (use the public IPs from the outputs):

```
http://<PublicS1_public_ip>
http://<PublicS2_public_ip>
```

Each page is served by that server. With the included `userdata.sh`, it shows the subnet ID.

### Test B: SSH into PublicS1

```bash
ssh -i keys/PublicS1-key.pem ec2-user@<PublicS1_public_ip>
```

The key file is already created with the right permissions (`0400`).
If your AMI does not use `ec2-user`, change the user name.

### Test C: Public to public (PublicS1 -> PublicS2)

Run these inside the PublicS1 SSH session, using PublicS2's **private IP**:

```bash
ping -c 4 <PublicS2_private_ip>
curl http://<PublicS2_private_ip>
```

### Test D: Public to private (PublicS1 -> PrivateS3)

```bash
ping -c 4 <PrivateS3_private_ip>
curl http://<PrivateS3_private_ip>
```

You should get replies from ping and the PrivateS3 index page from curl. This proves two things:

- The public servers can reach the private server through the local route and the security group rules.
- `PrivateS3` has internet access through the NAT gateway. It could only install Apache at boot by reaching the package repositories through `MY-NAT`.

### Test E: Private is not reachable from the internet

From your own laptop (not from PublicS1), try:

```bash
curl --max-time 5 http://<PrivateS3_private_ip>
```

It times out. `PrivateS3` has no public IP and no route from the internet.

---

## 7. Optional: SSH into PrivateS3 through PublicS1

By default `Private app` has no SSH rule, so you can't log in to `PrivateS3`. To use PublicS1 as a jump host,
add this rule to `security.tf` and run `terraform apply`:

```hcl
resource "aws_vpc_security_group_ingress_rule" "private_app_ssh" {
  security_group_id            = aws_security_group.private_app.id
  description                  = "SSH from Public Web servers"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.public_web.id
}
```

Then, from your laptop, load the key and use agent forwarding so the private key never leaves your machine:

```bash
ssh-add keys/PrivateS3-key.pem
ssh -A -i keys/PublicS1-key.pem ec2-user@<PublicS1_public_ip>
# now on PublicS1:
ssh ec2-user@<PrivateS3_private_ip>
```

---

## 8. Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `ping` hangs with no reply | No ICMP rule on the target's security group | Add the ICMP rules in `security.tf` (already included) |
| Ping or curl works with the private IP but not the public IP | Security group rules that reference a group only match private IPs | Use private IPs between servers |
| `curl` to a server hangs | The target's security group has no rule for port 80, or Apache isn't running yet | Check the security group, wait a few minutes, check `systemctl status httpd` |
| Page is empty or the connection is refused | User data failed or is still running | On the server, run `sudo cat /var/log/cloud-init-output.log` |
| PrivateS3's user data failed to install packages | Missing NAT route or missing outbound rule | Check the `Private-RT` route to `MY-NAT` and the egress rule on `Private app` |
| `Permission denied (publickey)` | Wrong key file or wrong user name | Use the matching `keys/<name>-key.pem` and the right default user for the AMI |
| `WARNING: UNPROTECTED PRIVATE KEY FILE` | Key file permissions are too open | `chmod 400 keys/*.pem` |

---

## 9. Clean up

The NAT gateway and the 3 `t3.small` instances cost money while they run. When you finish:

```bash
terraform destroy
```

---

## 10. Security notes

- SSH is open to `0.0.0.0/0` on the public servers. That is fine for a short lab, but for
  anything real, restrict it to your own IP.
- The generated private keys are stored in the Terraform state file as well as in `keys/`.
  Keep the state private and never commit `keys/`, `*.pem` or `*.tfstate` (the `.gitignore` already excludes them).
- Only HTTP and ping are allowed into `PrivateS3`, and only from the `Public Web` group.