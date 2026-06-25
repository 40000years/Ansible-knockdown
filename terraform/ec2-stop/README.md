# EC2 Power Management via OpenTofu

ระบบ Stop/Start EC2 พร้อมจัดการ NAT Gateway อัตโนมัติ ผ่าน Ansible Semaphore

---

## สถาปัตยกรรม (Architecture)

```
terraform/
  ec2-stop/     ← ลบ NAT GW → Stop EC2
  ec2-start/    ← Start EC2 → สร้าง NAT GW → Update Route Table
```

แต่ละโฟลเดอร์เป็น OpenTofu workspace แยกกัน มี State ใน S3 คนละ Key กัน

---

## ลำดับการทำงาน

### ⛔ Stop Workflow
```
1. ลบ NAT Gateway (+ รอจน deleted สมบูรณ์)
     ↓  (AWS จะ mark routes เป็น blackhole อัตโนมัติ)
2. Stop EC2 Instances
```

### ▶️ Start Workflow
```
1. Start EC2 Instances
     ↓  (พร้อมกัน)
2. รอ EC2 อยู่ใน running state
     ↓
3. สร้าง NAT Gateway ใหม่ใน Public Subnet
     ↓
4. อัปเดต Route Table 0.0.0.0/0 → NAT GW ใหม่
```

---

## วิธีตั้งค่า Semaphore Template

### Template 1: EC2 Stop + Delete NAT GW

> สร้าง Template โดยเลือก App = **OpenTofu Code**

| ฟิลด์ใน Semaphore UI | ค่าที่ต้องกรอก |
|---|---|
| **Name** | `EC2 Stop + Delete NAT GW` |
| **Repository** | `Ansible-knockdown` |
| **Subdirectory path** | `terraform/ec2-stop` |
| **OpenTofu options → apply** | ✅ เลือก `-auto-approve` |

**Extra Variables (ปรับตามต้องการ):**
```
instance_ids=["i-0ac9db71e7a4f2d52"]
nat_gateway_ids=["nat-XXXXXXXXXXXXXXXX"]
```

> ⚠️ **หา NAT GW ID**: ดูจาก Output ของ Task `AWS Inventory Dashboard` → ส่วน `nat_gateways`
> หรือดูจาก log ของ Start task บรรทัด `new_nat_gateway_id=...`

---

### Template 2: EC2 Start + Create NAT GW

> สร้าง Template โดยเลือก App = **OpenTofu Code**

| ฟิลด์ใน Semaphore UI | ค่าที่ต้องกรอก |
|---|---|
| **Name** | `EC2 Start + Create NAT GW` |
| **Repository** | `Ansible-knockdown` |
| **Subdirectory path** | `terraform/ec2-start` |
| **OpenTofu options → apply** | ✅ เลือก `-auto-approve` |


**Extra Variables (ปรับตามต้องการ):**
```
instance_ids=["i-0ac9db71e7a4f2d52"]
create_nat_gateway=true
nat_subnet_id="subnet-065d2b96694fd9180"
eip_allocation_id="eipalloc-XXXXXXXXXXXXXXXX"
route_table_id="rtb-0a3011115ffd2126d"
```

> ⚠️ **หา EIP Allocation ID**: รันใน terminal: 
> ```bash
> aws ec2 describe-addresses --query 'Addresses[*].[PublicIp,AllocationId]' --output table
> ```

---

## ตัวแปรที่ใช้บ่อย (Quick Reference)

### EC2 Instances ที่มีอยู่ใน Account
| Name | Instance ID | Private IP |
|---|---|---|
| Ubuntu24-1 | `i-0ac9db71e7a4f2d52` | 10.0.129.208 |
| Ubuntu26 | `i-0e5d32c1dc7b8710d` | 10.0.136.210 |
| Ubuntu26-2 | `i-0e5d7eae55aaa86ab` | 10.0.151.79 |

### Subnets ที่แนะนำสำหรับ NAT GW (Public)
| Subnet ID | AZ | CIDR |
|---|---|---|
| `subnet-065d2b96694fd9180` | ap-southeast-1a | 172.31.32.0/20 |
| `subnet-0f3008f6331dce702` | ap-southeast-1b | 172.31.16.0/20 |
| `subnet-05fec8ff35fefc11e` | ap-southeast-1c | 172.31.0.0/20 |

### Elastic IP ที่มีอยู่
| Public IP | Allocation ID |
|---|---|
| 52.220.235.218 | *(รันคำสั่งด้านบนเพื่อหา alloc ID)* |

---

## Notes

- หลังจากสั่ง Stop แล้ว **Route จะกลายเป็น blackhole** อัตโนมัติ (AWS behavior)
- เมื่อสั่ง Start, ระบบจะ **ลบ blackhole route เก่า** แล้วเพิ่ม route ใหม่ชี้ไปที่ NAT GW ใหม่
- NAT GW ใหม่จะใช้ EIP เดิม (allocation ID เดิม) แต่จะได้ NAT GW ID ใหม่
- **จดบันทึก NAT GW ID ใหม่** จาก Semaphore log (บรรทัด `new_nat_gateway_id=nat-xxx`) เพื่อใช้ตอน Stop ครั้งถัดไป
