# 🌐 Terraform: AWS EC2 Resources Fetch & Management

โฟลเดอร์นี้บรรจุโค้ด Terraform สำหรับดึงข้อมูล (Fetch) ของเครื่อง EC2 Instances ทั้งหมดใน Region ปลายทาง และเตรียมพร้อมสำหรับการนำเข้ามาจัดการภายใต้ Terraform (Import) โดยออกแบบมาให้รอบรับการทำงานผ่าน **Semaphore UI** และเครื่อง Local ได้อย่างปลอดภัยตามมาตรฐานระดับองค์กร

---

## 📁 โครงสร้างไฟล์ในโฟลเดอร์นี้
* `providers.tf` : ตั้งค่า AWS Provider และเทมเพลตสำหรับเก็บไฟล์สถานะผ่าน **Amazon S3 Backend**
* `variables.tf` : ตัวแปรสำหรับการปรับเปลี่ยน เช่น Region เริ่มต้น (`ap-southeast-1`)
* `main.tf` : โค้ดหลักในการดึงข้อมูล EC2 (`data.aws_instances`) และรูปแบบการทำ `import` เครื่องเข้ามาจัดการ
* `outputs.tf` : แสดงสรุปข้อมูล EC2 ทั้งหมด เช่น ID, Name Tag, Private/Public IP และ Instance Type

---

## 🛠️ วิธีการรันบนเครื่อง Local

ก่อนเริ่มต้น ตรวจสอบให้แน่ใจว่าคุณได้ตั้งค่า AWS Credentials ใน Terminal เรียบร้อยแล้ว (เช่น ผ่าน `aws configure` หรือ Export ตัวแปร env)

```bash
# 1. เข้ามายังโฟลเดอร์ terraform
cd terraform

# 2. เริ่มต้นติดตั้ง Terraform Provider
terraform init

# 3. ทดลองวางแผนและดึงข้อมูล EC2 ออกมาแสดงผล (ดูผลลัพธ์ผ่าน Console)
terraform plan
```

---

## 🚀 การตั้งค่าเพื่อรันผ่าน Semaphore UI

การทำให้ Terraform รันผ่าน **Semaphore** ได้อย่างราบรื่นและปลอดภัย มีขั้นตอนสำคัญ 2 ส่วน ดังนี้:

### 1. ตั้งค่าข้อมูลความปลอดภัย (AWS Credentials) ใน Semaphore
คุณต้องผ่าน AWS Keys ให้กับ Semaphore เพื่อให้มีสิทธิ์เข้าถึง AWS Account:
1. เข้าไปยัง **Semaphore Dashboard**
2. ไปที่เมนู **Environment** (หรือ Environment Variables ของ Project)
3. สร้าง Environment ใหม่สำหรับ AWS และเพิ่มตัวแปรต่อไปนี้:
   * `AWS_ACCESS_KEY_ID` (ประเภท: String / Secret)
   * `AWS_SECRET_ACCESS_KEY` (ประเภท: Secret)
   * `AWS_DEFAULT_REGION` = `ap-southeast-1`

### 2. การเปิดใช้งาน Amazon S3 Backend (สำคัญมาก ⚠️)
โดยธรรมชาติของ Semaphore เมื่อทำงานเสร็จคอนเทนเนอร์ตัวรันจะถูกทำลายทิ้ง หากเราบันทึกไฟล์สถานะ (`terraform.tfstate`) ไว้ในเครื่อง Local ของ Semaphore ไฟล์จะหายไปทันทีเมื่อรันเสร็จ ส่งผลให้รันครั้งต่อไปไม่สามารถระบุสถานะเดิมได้

**แนวทางแก้ไขที่ถูกต้อง:**
1. สร้าง **S3 Bucket** และ **DynamoDB Table** (สำหรับทำ State Locking) บนระบบ AWS ของคุณ
2. เปิดไฟล์ [providers.tf](file:///Users/user/Documents/GitHub/Ansible-knockdown/terraform/providers.tf) และทำการ Uncomment บล็อก `backend "s3"` จากนั้นแก้ไขค่าให้ตรงกับ AWS ของคุณ:
   ```hcl
   backend "s3" {
     bucket         = "ชื่อ-s3-bucket-ของคุณ"
     key            = "ec2-fetch/terraform.tfstate"
     region         = "ap-southeast-1"
     dynamodb_table = "ชื่อ-dynamodb-lock-table-ของคุณ"
   }
   ```
3. เมื่อเปิดใช้งาน S3 backend แล้ว ไฟล์ state จะถูกอัปโหลดและเก็บรักษาไว้บน AWS อย่างปลอดภัย ทำให้ทั้งการรันใน Semaphore และบนเครื่อง Local อ้างอิงไฟล์ตัวเดียวกันเสมอ

### 3. การสร้าง Task Template ใน Semaphore
สร้าง Task Template ใหม่ใน Semaphore โดยตั้งค่าดังนี้:
* **Repository:** เลือก Repository `Ansible-knockdown` และตั้งค่า Branch ไปที่ `Terraform`
* **Playbook Path (หรือ Command):** 
  * หาก Semaphore ของคุณตั้งค่าให้รัน shell หรือใช้ Terraform CLI โดยตรง ให้กำหนดคำสั่งรันดังนี้:
    ```bash
    cd terraform
    terraform init -no-color
    terraform plan -no-color
    ```
  * หรือหากเป็นงานแอปพลิเคชันหลัก ก็สามารถสั่ง `terraform apply -auto-approve -no-color` เพื่อประยุกต์ใช้การเปลี่ยนแปลงได้ทันที
* **Environment:** ตรวจสอบให้แน่ใจว่าได้เลือก Environment ของ AWS ที่คุณสร้างไว้ในข้อ 1 มาผูกกับ Task นี้ด้วย
